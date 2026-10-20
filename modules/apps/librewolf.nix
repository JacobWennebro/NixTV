# LibreWolf (Flatpak) as the default browser. Not a tile: Meta+S opens it.
{ config, lib, ... }:

let
  desktop = "io.gitlab.librewolf-community.desktop";
in
{
  options.nixtv.apps.librewolf.enable = lib.mkEnableOption "LibreWolf as the default browser" // {
    default = true;
  };

  config = lib.mkIf config.nixtv.apps.librewolf.enable {
    services.flatpak.packages = [ "io.gitlab.librewolf-community" ];

    # mimeapps.list for links opened by any app, plus KDE's
    # BrowserApplication, which Bigscreen otherwise sets to its own
    # (uninstalled) Aura browser in ~/.config/plasma-bigscreen/kdeglobals.
    # [$i] makes this system value win over that file.
    xdg.mime.defaultApplications = lib.genAttrs [
      "text/html"
      "application/xhtml+xml"
      "x-scheme-handler/http"
      "x-scheme-handler/https"
      "x-scheme-handler/about"
      "x-scheme-handler/unknown"
    ] (_: desktop);

    environment.etc."xdg/kdeglobals".text = ''
      [General]
      BrowserApplication[$i]=${desktop}
    '';
  };
}
