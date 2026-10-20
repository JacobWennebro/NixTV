# Your TV box: who it's for and what's on it. Turn a feature on or off by
# setting its `enable` and rebuilding; a module takes everything it added
# with it (tiles, icons, Flatpaks, services). Defaults are in modules/, and
# every app has a page in docs/apps/.
{
  nixtv = {
    hostName = "nixos-tv";
    user = "tv";
    timeZone = "UTC"; # e.g. "Europe/Stockholm", "America/New_York"
    locale = "en_US.UTF-8";
    keyboardLayout = "us";

    # Public SSH keys that may log in as the TV user.
    sshKeys = [ ];

    # On-screen keyboard layouts; more than one adds a language-switch key.
    onScreenKeyboard.locales = [ "en_US" ];

    apps = {
      youtube.enable = true; # Red (Flatpak) in TV mode, shown as "YouTube"
      iptv.enable = true; # iptvs, shown as "IPTV" (built from source)
      stremio.enable = true; # Stremio's Android TV app in Waydroid
      svtplay.enable = false; # SVT Play in Waydroid; needs a one-time manual download
      librewolf.enable = true; # default browser (Meta+S), not a tile
    };

    # Tailscale, with Trayscale and an exit-node item in the home screen's
    # top row.
    tailscale.enable = false;

    # No internet except through a Tailscale exit node (README, "The kill
    # switch"). Needs Tailscale; log in and pick an exit node first.
    tailscale.killswitch = {
      enable = false;
      allowLan = true; # keep SSH, casting and KDE Connect on the home network
    };
  };
}
