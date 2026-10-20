# iptvs as the "IPTV" tile. Sources (Xtream, Stalker, M3U) are added inside
# the app. Built from source (pkgs/iptvs), so the first build takes a while.
{ config, lib, pkgs, ... }:

let
  iptvs = pkgs.callPackage ../../pkgs/iptvs/package.nix { };
  home = config.users.users.${config.nixtv.user}.home;

  # assets/iptv.svg as a hicolor icon. No dash in the name: KDE would try a
  # "nixtv" fallback in Breeze before checking hicolor (see apps/youtube.nix).
  icon = pkgs.runCommand "nixtv-iptv-icon" { } ''
    install -Dm644 ${../../assets/iptv.svg} $out/share/icons/hicolor/scalable/apps/nixtv_iptv.svg
  '';

  # Launcher renamed to "IPTV" with that icon. Same file name as upstream's, so
  # it shadows it from ~/.local/share (rebuilding iptvs just to rename it would
  # recompile the whole Flutter app).
  desktop = pkgs.writeText "com.gchofficial.iptvs.desktop" ''
    [Desktop Entry]
    Type=Application
    Name=IPTV
    Comment=Live TV, movies and series (iptvs)
    Exec=${iptvs}/bin/iptvs
    Icon=nixtv_iptv
    Categories=AudioVideo;Video;Player;TV;
    Terminal=false
    StartupWMClass=com.gchofficial.iptvs
  '';
in
{
  options.nixtv.apps.iptv.enable = lib.mkEnableOption "the IPTV tile (iptvs)" // {
    default = true;
  };

  config = lib.mkIf config.nixtv.apps.iptv.enable {
    environment.systemPackages = [
      iptvs
      icon
    ];

    systemd.tmpfiles.rules = [
      "L+ ${home}/.local/share/applications/com.gchofficial.iptvs.desktop - - - - ${desktop}"
    ];

    nixtv.favorites.iptv = {
      order = 40;
      storageId = "com.gchofficial.iptvs.desktop";
      name = "IPTV";
      icon = "nixtv_iptv";
      desktopPath = "${home}/.local/share/applications/com.gchofficial.iptvs.desktop";
      entryPath = "iptvs";
    };
  };
}
