# YouTube (Red)

[Red](https://github.com/keshavbhatt/red) is an ad-free YouTube client developed by [Keshav Bhatt](https://github.com/keshavbhatt/).
NixTV installs it from Flathub and shows it as the **YouTube** tile, opening straight into its TV (leanback)
interface.

| | |
| --- | --- |
| Option | `nixtv.apps.youtube.enable` (default: on) |
| Source | Flathub, `com.ktechpit.red` |
| Module | [`modules/apps/youtube.nix`](../../modules/apps/youtube.nix) |

## How it's set up

- **Renamed launcher.** Red's own launcher is replaced (from `~/.local/share/applications`)
  by one called "YouTube", with the red YouTube icon (`assets/tv-youtube.svg`), that starts
  Red with `--tv`. Its extra actions open YouTube Music and Red's settings.
- **Fullscreen.** A KWin rule opens its window fullscreen and in front.
- **Updates.** Like all Flatpaks, Red updates weekly by itself.

## First boot

Nothing to do. Flatpaks install in the background after the first boot, and the tile
appears once Red is in (`journalctl -u flatpak-managed-install -f` shows progress).
