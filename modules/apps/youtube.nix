# Red (Flatpak), a YouTube client with a TV mode and no ads, as the
# "YouTube" tile.
{ config, lib, pkgs, ... }:

let
  home = config.users.users.${config.nixtv.user}.home;

  # The red YouTube logo (assets/tv-youtube.svg), installed into the hicolor
  # fallback theme so it works with any icon theme. No dash in the name: KDE
  # tries "tv-youtube" -> "tv" in Breeze before it checks hicolor.
  icon = pkgs.runCommand "tv-youtube-icon" { } ''
    install -Dm644 ${../../assets/tv-youtube.svg} \
      $out/share/icons/hicolor/scalable/apps/nixtv_youtube.svg
  '';

  # Red's launcher, presented as "YouTube" and opening straight into its TV
  # (leanback) mode. It shadows the Flatpak-exported entry of the same name,
  # which comes before system packages in XDG_DATA_DIRS, so it has to live in
  # ~/.local/share.
  desktop = pkgs.writeText "com.ktechpit.red.desktop" ''
    [Desktop Entry]
    Name=YouTube
    GenericName=YouTube Client
    Comment=YouTube on your TV (Red)
    Icon=nixtv_youtube
    Exec=flatpak run --branch=stable --command=red com.ktechpit.red --tv
    Terminal=false
    Type=Application
    Categories=AudioVideo;Video;Player;Qt;
    StartupWMClass=red
    StartupNotify=true
    X-Flatpak=com.ktechpit.red
    Actions=Music;Settings;

    [Desktop Action Music]
    Name=Open YouTube Music
    Exec=flatpak run --branch=stable --command=red com.ktechpit.red --music

    [Desktop Action Settings]
    Name=Settings
    Exec=flatpak run --branch=stable --command=red com.ktechpit.red --settings
  '';
in
{
  options.nixtv.apps.youtube.enable = lib.mkEnableOption "the YouTube tile (Red, a Flatpak)" // {
    default = true;
  };

  config = lib.mkIf config.nixtv.apps.youtube.enable {
    services.flatpak.packages = [ "com.ktechpit.red" ];
    nixtv.fullscreenApps = [ "com.ktechpit.red" ];

    environment.systemPackages = [ icon ];
    systemd.tmpfiles.rules = [
      "L+ ${home}/.local/share/applications/com.ktechpit.red.desktop - - - - ${desktop}"
    ];

    nixtv.favorites.youtube = {
      order = 30;
      storageId = "com.ktechpit.red.desktop";
      name = "YouTube";
      icon = "nixtv_youtube";
      desktopPath = "${home}/.local/share/applications/com.ktechpit.red.desktop";
      entryPath = "flatpak run --branch=stable --command=red com.ktechpit.red --tv";
    };
  };
}
