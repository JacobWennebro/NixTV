# Waydroid (Android in a container) for the Android app tiles (apps/stremio.nix,
# apps/svtplay.nix turn it on). The session starts with the desktop, so apps
# open warm. Shared fixes here: video codecs, Back on Esc, a hidden navigation
# bar, LeanKey as the keyboard, and a watchdog for a framework deadlock.
#
# Android itself (~1 GB of images) downloads by itself on the first boot with
# internet (waydroid-init below); with the kill switch, once an exit node is
# selected. Follow it with `journalctl -u waydroid-init -f`.
#
# Turning it off leaves Android's data behind; to remove it:
# `sudo rm -rf /var/lib/waydroid ~/.local/share/waydroid`.
{
  config,
  lib,
  pkgs,
  ...
}:

let
  cfg = config.nixtv.waydroid;
  waydroid = config.virtualisation.waydroid.package;

  # LeanKey: an on-screen keyboard made for TV remotes (D-pad), replacing
  # Android's phone keyboard. Plasma's own keyboard can't be used: Waydroid's
  # compositor bridge doesn't speak Wayland's text-input protocols, so Plasma
  # never learns that an Android text field wants a keyboard.
  # https://github.com/yuliskov/LeanKeyboard
  leankey = pkgs.fetchurl {
    url = "https://github.com/yuliskov/LeanKeyboard/releases/download/6.1.31/LeanKeyboard_v6.1.31_playstore_r.apk";
    hash = "sha256-WpBSn8rlXGZBKPs251L5DoTRWCZuzthQhFlMHTNqFGg=";
  };
  leankeyPackage = "org.liskovsoft.androidtv.rukeyboard";
  leankeyIme = "${leankeyPackage}/com.liskovsoft.leankeyboard.ime.LeanbackImeService";

  # A root shell in Android, which prepare runs through a password-free sudo
  # rule (it takes no arguments). Android settings: LeanKey as the only
  # keyboard, and no crash/"not responding" dialogs. Waydroid only gives the
  # launched app a window, so such a dialog had nowhere to draw: drawing it
  # blocked Android's system server until its watchdog restarted all of
  # Android. Without the dialog, Android stops a hung app instead.
  configureAndroid = pkgs.writeShellApplication {
    name = "waydroid-configure-android";
    runtimeInputs = [ waydroid ];
    text = ''
      waydroid shell -- sh -c '
        ime enable ${leankeyIme} >/dev/null
        ime set ${leankeyIme} >/dev/null
        ime disable com.android.inputmethod.latin/.LatinIME >/dev/null
        settings put global hide_error_dialogs 1
      '
    '';
  };

  # Wait for Android (starting the session service if it isn't running),
  # then install or update the APKs (nixtv.waydroid.apks and LeanKey) and set
  # up Android. Runs when the session service starts, so tiles normally find
  # everything ready; their launchers run it again.
  prepare = pkgs.writeShellApplication {
    name = "waydroid-prepare";
    runtimeInputs = [
      waydroid
      pkgs.coreutils
      pkgs.gnugrep
      pkgs.systemd
    ];
    # `waydroid app list` exits 0 even with no session, so readiness and the
    # install are checked by what Android actually lists.
    text = ''
      ready() { waydroid app list 2>/dev/null | grep -q "packageName:"; }
      installed() { waydroid app list 2>/dev/null | grep -q "packageName: $1$"; }

      # ensure <package> <apk>: install, or update when the APK changed.
      ensure() {
        stamp="$HOME/.local/share/waydroid/$1-installed"
        if ! installed "$1" || [ "$(cat "$stamp" 2>/dev/null)" != "$2" ]; then
          waydroid app install "$2"
          for _ in $(seq 1 30); do installed "$1" && break; sleep 2; done
          installed "$1" && { mkdir -p "$(dirname "$stamp")"; echo "$2" > "$stamp"; }
        fi
      }

      if ! ready; then
        systemctl --user start --no-block waydroid-session.service
        for _ in $(seq 1 90); do ready && break; sleep 2; done
      fi

      ${lib.concatStrings (lib.mapAttrsToList (pkg: apk: "ensure ${pkg} ${apk}\n") cfg.apks)}
      ensure ${leankeyPackage} ${leankey}
      installed ${leankeyPackage} && { /run/wrappers/bin/sudo -n ${configureAndroid}/bin/waydroid-configure-android || true; }
    '';
  };

  # Waydroid's hwcomposer (vendor image 20260927 and older) can deadlock
  # Android's display stack when an app's window gets keyboard focus while
  # Android handles a display hotplug, which it does on every window
  # configure, so on most launches. Its Wayland thread calls system_server's
  # setFocusedTask() while holding its window lock; system_server holds the
  # window manager lock waiting on SurfaceFlinger, which waits on the
  # hwcomposer for that window lock. After a minute the watchdog restarts
  # Android's framework, and Android then has no network until the session
  # restarts. Fixed upstream (android_hardware_waydroid a3e4239, 2026-10-18)
  # but not yet in a released vendor image. Until then: when system_server
  # restarts but Android itself (its init) didn't, restart the session.
  watchdog = pkgs.writeShellApplication {
    name = "waydroid-framework-watchdog";
    runtimeInputs = [
      pkgs.procps
      pkgs.systemd
    ];
    text = ''
      # "<Android init pid>:<system_server pid>", from the host's view.
      # system_server's parent is zygote, whose parent is Android's init.
      android() {
        ss=$(pgrep -xo system_server) || return 1
        zygote=$(ps -o ppid= -p "$ss" | tr -d ' ')
        init=$(ps -o ppid= -p "$zygote" | tr -d ' ')
        echo "$init:$ss"
      }

      last=""
      while sleep 15; do
        cur=$(android) || { last=""; continue; }
        if [ -n "$last" ] && [ "''${last%%:*}" = "''${cur%%:*}" ] && [ "$last" != "$cur" ]; then
          echo "Android's framework restarted (system_server ''${last#*:} -> ''${cur#*:}); restarting the Waydroid session"
          systemctl --user --no-block restart waydroid-session.service
          last=""
          continue
        fi
        last=$cur
      done
    '';
  };

  # Runs before each container start (so it also covers a vendor image from
  # a later `waydroid upgrade`). Fixes, in order:
  #
  # - The bottom navigation bar: hidden (as on a device with hardware keys),
  #   for a fullscreen TV picture. Back is the remote's Back key, or Esc.
  #
  # - Video: Waydroid's arm64 vendor image declares the OMX codec HAL in its
  #   VINTF manifest but ships no OMX service, and Waydroid (on gbm gralloc)
  #   sets debug.stagefright.ccodec=0, which turns off the Codec2 software
  #   codecs that do exist. Every MediaCodec lookup then hung in mediaserver
  #   waiting for OMX forever: the UI ran fine but no video ever played. Mask
  #   the OMX entry with a vendor overlay and turn Codec2 back on, only when
  #   the vendor image really lacks an OMX service.
  setup = pkgs.writeShellApplication {
    name = "waydroid-setup";
    runtimeInputs = [
      pkgs.e2fsprogs
      pkgs.gawk
      pkgs.gnugrep
      pkgs.gnused
      pkgs.coreutils
    ];
    text = ''
      dir=/var/lib/waydroid
      img=$dir/images/vendor.img
      cfg=$dir/waydroid.cfg
      base=$dir/waydroid_base.prop
      overlay=$dir/overlay/vendor/etc/vintf/manifest.xml
      [ -f "$img" ] && [ -f "$cfg" ] || exit 0  # before `waydroid init`

      # [properties] in waydroid.cfg survives `waydroid upgrade`; the base
      # prop file is what this boot reads (it's only rebuilt on upgrade).
      setprop() {
        grep -q '^\[properties\]' "$cfg" || printf '\n[properties]\n' >> "$cfg"
        sed -i "/^$1 *=/d; /^\[properties\]/a $1 = $2" "$cfg"
        sed -i "/^$1=/d" "$base"
        echo "$1=$2" >> "$base"
      }

      setprop qemu.hw.mainkeys 1

      # Esc as a real Back key on Waydroid's keyboard. Android's default map
      # only falls back from Escape to Back when the app ignores Escape, and
      # Stremio's player swallows it, leaving no way out of the player.
      # Android picks a keylayout named after the input device over Generic.kl.
      kl=$dir/overlay/system/usr/keylayout/wayland_keyboard.kl
      mkdir -p "$(dirname "$kl")"
      debugfs -R "cat /system/usr/keylayout/Generic.kl" "$dir/images/system.img" 2>/dev/null \
        | sed -E 's/^key 1 +ESCAPE$/key 1     BACK/' > "$kl.tmp"
      if grep -q '^key 1     BACK$' "$kl.tmp"; then mv "$kl.tmp" "$kl"; else rm -f "$kl.tmp" "$kl"; fi

      # Waydroid lists /dev/dma_heap/* in config_nodes only at init/upgrade,
      # so a heap that appeared later (system_heap below) never got bound.
      nodes=$dir/lxc/waydroid/config_nodes
      for heap in /dev/dma_heap/*; do
        [ -e "$heap" ] && [ -f "$nodes" ] || continue
        grep -q " $heap " "$nodes" \
          || echo "lxc.mount.entry = $heap ''${heap#/} none bind,create=file,optional 0 0" >> "$nodes"
      done

      manifest=$(debugfs -R "cat /etc/vintf/manifest.xml" "$img" 2>/dev/null)
      if ! grep -q "android.hardware.media.omx" <<<"$manifest" \
        || debugfs -R "ls -p /bin/hw" "$img" 2>/dev/null | grep -qi omx; then
        rm -f "$overlay"
        exit 0
      fi

      # Drop the <hal> block that names the OMX HAL.
      mkdir -p "$(dirname "$overlay")"
      awk '
        /<hal[ >]/ { buf = $0; inhal = 1; next }
        inhal {
          buf = buf "\n" $0
          if (/<\/hal>/) { inhal = 0; if (buf !~ /android\.hardware\.media\.omx/) print buf }
          next
        }
        { print }
      ' <<<"$manifest" > "$overlay"

      setprop debug.stagefright.ccodec 4
    '';
  };
in
{
  options.nixtv.waydroid = {
    enable = lib.mkEnableOption "Waydroid, for the Android app tiles (turned on by the apps that need it)";

    apks = lib.mkOption {
      type = lib.types.attrsOf lib.types.path;
      default = { };
      example = lib.literalExpression ''{ "com.stremio.one" = pkgs.fetchurl { ... }; }'';
      description = "APKs (by Android package name) to install, and update when they change, as Android starts.";
    };

    prepare = lib.mkOption {
      type = lib.types.package;
      readOnly = true;
      internal = true;
      description = "Waits for Android and installs nixtv.waydroid.apks (bin/waydroid-prepare); for launchers.";
    };
  };

  config = lib.mkIf cfg.enable {
    nixtv.waydroid.prepare = prepare;

    virtualisation.waydroid.enable = true;
    # On Python 3.14 the session manager aborted with heap corruption inside
    # dbus-python's GLib main loop, killing the session. Built on 3.13 instead.
    # Android's network (NAT) always set up with nftables: recent kernels
    # (7.x, linuxPackages_latest) no longer have legacy iptables, so with the
    # NixOS firewall in iptables mode Android had no network at all.
    virtualisation.waydroid.package = pkgs.waydroid.override {
      withNftables = true;
      python3Packages = pkgs.python313Packages;
    };

    # Keep Android running from login so apps open in seconds, not ~30.
    # It holds about 1 GB of RAM while idle.
    systemd.user.services.waydroid-session = {
      description = "Waydroid session (kept warm for the Android apps)";
      wantedBy = [ "graphical-session.target" ];
      partOf = [ "graphical-session.target" ];
      after = [ "graphical-session.target" ];
      # A rebuild restarting Android mid-session once hung for minutes and left
      # the VM out of memory; changes apply at the next login instead.
      restartIfChanged = false;
      # Not before Android is downloaded; waydroid-init starts it then.
      unitConfig.ConditionPathExists = "/var/lib/waydroid/waydroid.cfg";
      serviceConfig = {
        ExecStart = "${waydroid}/bin/waydroid session start";
        TimeoutStopSec = 30;
        ExecStartPost = "${prepare}/bin/waydroid-prepare";
        ExecStop = "${waydroid}/bin/waydroid session stop";
        TimeoutStartSec = 300;
        # Also after a clean exit: the session ends quietly when the container
        # restarts (e.g. a rebuild turning the kill switch on or off).
        Restart = "always";
        RestartSec = 10;
      };
    };

    # See the watchdog above. Restarted along with the session, so it starts
    # watching afresh each time.
    systemd.user.services.waydroid-framework-watchdog = {
      description = "Restart the Waydroid session after Android's framework restarts";
      wantedBy = [ "waydroid-session.service" ];
      partOf = [ "waydroid-session.service" ];
      after = [ "waydroid-session.service" ];
      serviceConfig = {
        ExecStart = "${watchdog}/bin/waydroid-framework-watchdog";
        Restart = "on-failure";
      };
    };

    security.sudo.extraRules = [
      {
        users = [ config.nixtv.user ];
        commands = [
          {
            command = "${configureAndroid}/bin/waydroid-configure-android";
            options = [ "NOPASSWD" ];
          }
        ];
      }
    ];

    # Codec2 allocates its buffers from a DMA-BUF heap (Waydroid binds
    # /dev/dma_heap/* into the container). NixOS builds the system heap as a
    # module that nothing loads, so every decoder failed to start (NO_MEMORY,
    # "cannot allocate memory at all"): Exo showed "Decoder init failed".
    # waydroid-setup adds the heap to the container's device list.
    boot.kernelModules = [ "system_heap" ];

    systemd.services.waydroid-container.preStart = "${setup}/bin/waydroid-setup";

    # Download Android the first time there's internet: `waydroid init`, only
    # while it has never run. Without internet (or, with the kill switch,
    # before an exit node is picked) it fails and tries again every 5 minutes.
    # Then the container restarts with it and the TV user's Android session
    # starts, which installs the apps; no reboot needed.
    systemd.services.waydroid-init = {
      description = "Download Android for Waydroid (first boot)";
      wantedBy = [ "multi-user.target" ];
      wants = [ "network-online.target" ];
      after = [ "network-online.target" ];
      before = [ "waydroid-container.service" ];
      unitConfig = {
        ConditionPathExists = "!/var/lib/waydroid/waydroid.cfg";
        StartLimitIntervalSec = 0; # keep retrying, however long it takes
      };
      serviceConfig = {
        Type = "oneshot";
        ExecStart = "${waydroid}/bin/waydroid init";
        ExecStartPost = [
          "${pkgs.systemd}/bin/systemctl restart waydroid-container.service"
          "-${pkgs.systemd}/bin/systemctl --user --machine=${config.nixtv.user}@ start waydroid-session.service"
        ];
        TimeoutStartSec = "1h";
        Restart = "on-failure";
        RestartSec = "5min";
      };
    };

    # Don't fake the "leanback" (TV device) feature in Waydroid's overlay: it
    # makes SystemUI skip its tablet UI, which then crashes in a loop (null
    # CentralSurfaces) and nothing can be shown. Waydroid only ships tablet
    # builds; TV interfaces come from the apps themselves. This removes the
    # file an earlier version of this setup put there.
    systemd.tmpfiles.rules = [
      "r /var/lib/waydroid/overlay/system/etc/permissions/android.software.leanback.xml"
    ];

    # A clear error instead of a missing-attribute one on other CPUs.
    assertions = [
      {
        assertion = lib.elem pkgs.stdenv.hostPlatform.system [
          "aarch64-linux"
          "x86_64-linux"
        ];
        message = "The Android apps (Waydroid) are set up only for aarch64 and x86_64.";
      }
    ];
  };
}
