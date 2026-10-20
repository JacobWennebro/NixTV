# Stremio: its Android TV app in Waydroid (core/waydroid.nix), as the
# "Stremio" tile.
{
  config,
  lib,
  pkgs,
  ...
}:

let
  cfg = config.nixtv.apps.stremio;
  waydroid = config.virtualisation.waydroid.package;
  version = "1.10.4";

  # Android TV build from https://www.stremio.com/downloads
  apk =
    {
      aarch64-linux = pkgs.fetchurl {
        url = "https://dl.strem.io/android/v${version}-androidTV/com.stremio.one-${version}-33145732-arm64-v8a.apk";
        hash = "sha256-yq9Pq6QjpHwxdO2gi5QFeVbOMq9hbGN3s0hfT13smTw=";
      };
      x86_64-linux = pkgs.fetchurl {
        url = "https://dl.strem.io/android/v${version}-androidTV/com.stremio.one-${version}-34194308-x86_64.apk";
        hash = "sha256-Op+GZGuhj08RBz37sB4QsdQBnnjYm6WOw955829s/Iw=";
      };
    }
    .${pkgs.stdenv.hostPlatform.system};

  # A root shell stopping Stremio (see the launcher), through a password-free
  # sudo rule (no arguments).
  stopStremio = pkgs.writeShellApplication {
    name = "waydroid-stop-stremio";
    runtimeInputs = [ waydroid ];
    text = "waydroid shell -- am force-stop com.stremio.one";
  };

  # Closing Stremio's window doesn't stop the app in Android: it stays
  # "visible", drawing into a surface nothing shows (dequeueBuffer timeouts),
  # and reopening it gave a black window. So with no Stremio window open,
  # stop the app and start it fresh (~3 s with Android already up). With a
  # window still open (only the home screen in front), just bring it back.
  launcher = pkgs.writeShellApplication {
    name = "stremio";
    runtimeInputs = [
      waydroid
      pkgs.kdotool
      pkgs.gnugrep
    ];
    text = ''
      ${config.nixtv.waydroid.prepare}/bin/waydroid-prepare
      if ! kdotool search --class '^waydroid\.com\.stremio\.one$' 2>/dev/null | grep -q .; then
        /run/wrappers/bin/sudo -n ${stopStremio}/bin/waydroid-stop-stremio || true
      fi
      exec waydroid app launch com.stremio.one
    '';
  };

  # assets/stremio.svg (Stremio's logo) as a hicolor icon; the name has no
  # dash, see apps/youtube.nix.
  icon = pkgs.runCommand "nixtv-stremio-icon" { } ''
    install -Dm644 ${../../assets/stremio.svg} $out/share/icons/hicolor/scalable/apps/nixtv_stremio.svg
  '';

  tile = pkgs.makeDesktopItem {
    name = "nixtv-stremio";
    desktopName = "Stremio";
    comment = "Movies and series (Stremio's Android TV app)";
    icon = "nixtv_stremio";
    exec = "${launcher}/bin/stremio";
    # Waydroid names the app's window after the Android package.
    startupWMClass = "waydroid.com.stremio.one";
    categories = [
      "AudioVideo"
      "Video"
    ];
  };
in
{
  options.nixtv.apps.stremio.enable = lib.mkEnableOption "the Stremio tile (its Android TV app in Waydroid)" // {
    default = true;
  };

  config = lib.mkIf cfg.enable {
    nixtv.waydroid.enable = lib.mkDefault true;
    nixtv.waydroid.apks."com.stremio.one" = apk;

    environment.systemPackages = [
      tile
      icon
    ];

    security.sudo.extraRules = [
      {
        users = [ config.nixtv.user ];
        commands = [
          {
            command = "${stopStremio}/bin/waydroid-stop-stremio";
            options = [ "NOPASSWD" ];
          }
        ];
      }
    ];

    # The window is opened by Waydroid's session, not the tile's process, so
    # KWin's focus-stealing prevention left it behind the home screen.
    nixtv.fullscreenApps = [ "waydroid.com.stremio.one" ];

    nixtv.favorites.stremio = {
      order = 20;
      storageId = "nixtv-stremio.desktop";
      name = "Stremio";
      icon = "nixtv_stremio";
      desktopPath = "/run/current-system/sw/share/applications/nixtv-stremio.desktop";
      entryPath = "${launcher}/bin/stremio";
    };

    assertions = [
      {
        assertion = config.nixtv.waydroid.enable;
        message = "nixtv.apps.stremio runs in Waydroid: don't turn nixtv.waydroid off while it's on.";
      }
    ];
  };
}
