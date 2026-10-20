# SVT Play: its Android app in Waydroid (core/waydroid.nix), as the
# "SVT Play" tile. Off by default: it needs a manual download (below), and
# most of it only plays from Sweden.
#
# - SVT's own programmes play; bought-in films and series that SVT protects
#   with Widevine DRM (a few percent of the catalogue) fail with a licence
#   error, since Waydroid has no Widevine.
# - Most of the catalogue is only shown from Sweden: pick a Swedish exit node.
# - TV interface: the app shows it only when Android's UI mode is
#   "television" (its isTv() check), and making Waydroid report that (the
#   android.hardware.type.television feature) crashes SystemUI in a loop, just
#   like leanback does (see core/waydroid.nix). So the build patches
#   isTv() to always return true. A patched APK needs a new signature: each
#   machine signs it with its own key, made on first install and kept in
#   /var/lib/nixtv-svtplay (not the world-readable Nix store), so later
#   versions update in place. The app checks no signatures of its own.
#
# One-time manual step per machine: APKMirror sits behind a bot check, so Nix
# can't download the APK itself. See `apkm` below, or point
# nixtv.apps.svtplay.apkUrl at your own copy.
{
  config,
  lib,
  pkgs,
  ...
}:

let
  cfg = config.nixtv.apps.svtplay;
  home = config.users.users.${config.nixtv.user}.home;
  package = "se.svt.android.svtplay";
  version = "15.5.0";
  waydroid = config.virtualisation.waydroid.package;

  # The universal APK bundle (base APK + per-CPU, density and language splits)
  # from https://www.apkmirror.com/apk/sveriges-television-ab/svt-play/
  # (variant: universal, 120-480dpi, Android 12L+). Signed by SVT
  # (certificate SHA-256 32cf985b…5f3c). The hash pins the file, so it can
  # come from anywhere: nixtv.apps.svtplay.apkUrl, or added by hand.
  apkmName = "svtplay-${version}.apkm";
  apkmHash = "sha256-acHPj6H9AigBniGkRPGTZXTy13eRLpav0QJvRcc3Gso=";
  apkm =
    if cfg.apkUrl != null then
      pkgs.fetchurl {
        name = apkmName;
        url = cfg.apkUrl;
        hash = apkmHash;
      }
    else
      pkgs.requireFile {
        name = apkmName;
        hash = apkmHash;
        message = ''
          SVT Play ${version} isn't in the Nix store yet. APKMirror blocks scripted
          downloads, so download it in a browser:

            https://www.apkmirror.com/apk/sveriges-television-ab/svt-play/svt-play-15-5-0-release/svt-play-15-5-0-android-apk-download/

          then add it to the store under the name Nix expects:

            mv se.svt.android.svtplay_${version}-*_apkmirror.com.apkm svtplay-${version}.apkm
            nix-store --add-fixed sha256 svtplay-${version}.apkm

          Or serve your copy somewhere you control and set nixtv.apps.svtplay.apkUrl,
          or turn SVT Play off with nixtv.apps.svtplay.enable = false.
        '';
      };

  # The splits this machine needs: its CPU's native code, every density
  # (Android picks), and Swedish and English text.
  abi =
    {
      aarch64-linux = "arm64_v8a";
      x86_64-linux = "x86_64";
    }
    .${pkgs.stdenv.hostPlatform.system};

  # Apktool's release jar: decodes the code to smali and rebuilds the APK.
  # (nixpkgs' apktool needs aapt, which isn't built for aarch64; resources
  # stay undecoded here, so aapt is never run.)
  apktool = pkgs.fetchurl {
    url = "https://github.com/iBotPeaches/Apktool/releases/download/v3.0.3/apktool_3.0.3.jar";
    hash = "sha256-2/kwsHbGub4I1XxEnKzvw73Wtx69WbMGb8Dh9bFPlCM=";
  };

  # The base APK with isTv() (se.svt.svtplay.util.extensions.ContextExtensionsKt)
  # returning true. Unsigned: install-time signing replaces SVT's signature.
  tvBase =
    pkgs.runCommand "svtplay-${version}-tv-base.apk"
      {
        nativeBuildInputs = [
          pkgs.jdk_headless
          pkgs.unzip
          pkgs.perl
        ];
      }
      ''
        unzip -q ${apkm} base.apk
        export HOME=$TMPDIR # apktool keeps a framework cache there
        java -jar ${apktool} d -r -o dec base.apk
        f=$(grep -rl '^\.class .*Lse/svt/svtplay/util/extensions/ContextExtensionsKt;' dec/smali*)
        perl -0pi -e '
          s/(\.method public static final isTv\(Landroid\/content\/Context;\)Z\n).*?(\.end method)/$1    .locals 1\n\n    const\/4 v0, 0x1\n\n    return v0\n$2/s
            or die "isTv() not found\n"
        ' "$f"
        java -jar ${apktool} b -o $out dec
      '';

  apks = pkgs.runCommand "svtplay-${version}-apks" { nativeBuildInputs = [ pkgs.unzip ]; } ''
    mkdir $out
    unzip -j ${apkm} -d $out split_config.${abi}.apk \
      'split_config.*dpi.apk' split_config.sv.apk split_config.en.apk
    cp ${tvBase} $out/base.apk
  '';

  # Sign the APKs with this machine's key and install them. `waydroid app
  # install` takes a single APK, so the splits go in with Android's own
  # `pm install`, which reads them from Android's /data. Root, through a
  # password-free sudo rule (no arguments).
  installApks = pkgs.writeShellApplication {
    name = "waydroid-install-svtplay";
    runtimeInputs = [
      waydroid
      pkgs.coreutils
      pkgs.gnugrep
      pkgs.jdk_headless
      pkgs.apksigner
    ];
    text = ''
      keydir=/var/lib/nixtv-svtplay
      ks=$keydir/signing.p12
      if [ ! -f "$ks" ]; then
        install -d -m 700 "$keydir"
        keytool -genkeypair -keystore "$ks" -storetype PKCS12 -storepass nixtv-svtplay \
          -alias svtplay -keyalg RSA -keysize 2048 -validity 36500 \
          -dname "CN=nixtv SVT Play"
        chmod 600 "$ks"
      fi

      dir=${home}/.local/share/waydroid/data/local/tmp/svtplay
      rm -rf "$dir"
      mkdir -p "$dir"
      for apk in ${apks}/*.apk; do
        apksigner sign --ks "$ks" --ks-pass pass:nixtv-svtplay \
          --in "$apk" --out "$dir/$(basename "$apk")"
      done
      rm -f "$dir"/*.idsig
      chmod 644 "$dir"/*.apk

      pmInstall() { waydroid shell -- sh -c 'pm install /data/local/tmp/svtplay/*.apk' 2>&1; }
      out=$(pmInstall) || true
      echo "$out"
      # Signed by someone else (SVT's own app, or a lost key): replace it.
      # This drops the app's data (the chosen profile, the consent choice).
      if grep -q INSTALL_FAILED_UPDATE_INCOMPATIBLE <<<"$out"; then
        waydroid shell -- pm uninstall ${package}
        pmInstall
      fi
      rm -rf "$dir"
    '';
  };

  stopApp = pkgs.writeShellApplication {
    name = "waydroid-stop-svtplay";
    runtimeInputs = [ waydroid ];
    text = "waydroid shell -- am force-stop ${package}";
  };

  # Wait for Android (starting the session service if it isn't running),
  # then install or update the app. Same checks as Stremio's prepare.
  prepare = pkgs.writeShellApplication {
    name = "waydroid-svtplay-prepare";
    runtimeInputs = [
      waydroid
      pkgs.coreutils
      pkgs.gnugrep
      pkgs.systemd
    ];
    text = ''
      ready() { waydroid app list 2>/dev/null | grep -q "packageName:"; }
      installed() { waydroid app list 2>/dev/null | grep -q "packageName: ${package}$"; }

      if ! ready; then
        systemctl --user start --no-block waydroid-session.service
        for _ in $(seq 1 90); do ready && break; sleep 2; done
      fi

      stamp="$HOME/.local/share/waydroid/${package}-installed"
      if ! installed || [ "$(cat "$stamp" 2>/dev/null)" != "${apks}" ]; then
        /run/wrappers/bin/sudo -n ${installApks}/bin/waydroid-install-svtplay || true
        for _ in $(seq 1 30); do installed && break; sleep 2; done
        installed && { mkdir -p "$(dirname "$stamp")"; echo "${apks}" > "$stamp"; }
      fi
    '';
  };

  # Like Stremio's: with no SVT Play window open, restart the app (a closed
  # window leaves it drawing into nothing, and reopening showed black); with
  # one open, just bring it back.
  launcher = pkgs.writeShellApplication {
    name = "svtplay";
    runtimeInputs = [
      waydroid
      pkgs.kdotool
      pkgs.gnugrep
    ];
    text = ''
      ${prepare}/bin/waydroid-svtplay-prepare
      if ! kdotool search --class '^waydroid\.se\.svt\.android\.svtplay$' 2>/dev/null | grep -q .; then
        /run/wrappers/bin/sudo -n ${stopApp}/bin/waydroid-stop-svtplay || true
      fi
      exec waydroid app launch ${package}
    '';
  };

  # assets/svtplay.png (the app's own icon) as a hicolor icon; the name has
  # no dash, see apps/youtube.nix.
  icon = pkgs.runCommand "nixtv-svtplay-icon" { } ''
    install -Dm644 ${../../assets/svtplay.png} $out/share/icons/hicolor/512x512/apps/nixtv_svtplay.png
  '';

  tile = pkgs.makeDesktopItem {
    name = "nixtv-svtplay";
    desktopName = "SVT Play";
    comment = "SVT's programmes (SVT Play's Android app)";
    icon = "nixtv_svtplay";
    exec = "${launcher}/bin/svtplay";
    startupWMClass = "waydroid.${package}";
    categories = [
      "AudioVideo"
      "Video"
    ];
  };
in
{
  options.nixtv.apps.svtplay = {
    enable = lib.mkEnableOption "the SVT Play tile (its Android app in Waydroid; needs a one-time manual download)";
    apkUrl = lib.mkOption {
      type = lib.types.nullOr lib.types.str;
      default = null;
      example = "http://nas.tailnet.ts.net/svtplay-15.5.0.apkm";
      description = ''
        Where to download the APK bundle from, for example your own copy on
        your tailnet, instead of adding it to the Nix store by hand. The file
        must match the pinned hash. Keep it private: it's SVT's app.
      '';
    };
  };

  config = lib.mkIf cfg.enable {
    nixtv.waydroid.enable = lib.mkDefault true;

    environment.systemPackages = [
      tile
      icon
    ];

    # Install or update the app as soon as Android is up, so the tile normally
    # finds it ready (the launcher checks again).
    systemd.user.services.waydroid-svtplay-install = {
      description = "Install SVT Play into Waydroid";
      wantedBy = [ "waydroid-session.service" ];
      after = [ "waydroid-session.service" ];
      serviceConfig = {
        Type = "oneshot";
        ExecStart = "${prepare}/bin/waydroid-svtplay-prepare";
        TimeoutStartSec = 300;
      };
    };

    security.sudo.extraRules = [
      {
        users = [ config.nixtv.user ];
        commands = [
          {
            command = "${installApks}/bin/waydroid-install-svtplay";
            options = [ "NOPASSWD" ];
          }
          {
            command = "${stopApp}/bin/waydroid-stop-svtplay";
            options = [ "NOPASSWD" ];
          }
        ];
      }
    ];

    # Without this, the window opened as a short strip, not fullscreen.
    nixtv.fullscreenApps = [ "waydroid.${package}" ];

    nixtv.favorites.svtplay = {
      order = 10;
      storageId = "nixtv-svtplay.desktop";
      name = "SVT Play";
      icon = "nixtv_svtplay";
      desktopPath = "/run/current-system/sw/share/applications/nixtv-svtplay.desktop";
      entryPath = "${launcher}/bin/svtplay";
    };

    assertions = [
      {
        assertion = config.nixtv.waydroid.enable;
        message = "nixtv.apps.svtplay runs in Waydroid: don't turn nixtv.waydroid off while it's on.";
      }
    ];
  };
}
