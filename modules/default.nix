# Everything the TV box can do. Each feature is an option under `nixtv`
# (set them in config.nix); importing a module never turns anything on by
# itself, except the core.
#
# The import order is also the order list options merge in (Flatpak apps,
# fullscreen window classes), so keep apps after the core.
{
  imports = [
    ./core/base.nix
    ./core/tv.nix
    ./core/bigscreen.nix
    ./core/flatpak.nix
    ./core/waydroid.nix
    ./apps/youtube.nix
    ./tailscale
    ./tailscale/killswitch.nix
    ./apps/librewolf.nix
    ./apps/stremio.nix
    ./apps/svtplay.nix
    ./apps/iptv.nix
  ];
}
