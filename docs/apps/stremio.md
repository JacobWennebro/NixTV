# Stremio

Stremio's **Android TV app**, running in [Waydroid](https://waydro.id) (Android in a
container), as the **Stremio** tile.

| | |
| --- | --- |
| Option | `nixtv.apps.stremio.enable` (default: on) |
| Source | the Android TV APK from [stremio.com/downloads](https://www.stremio.com/downloads) |
| Module | [`modules/apps/stremio.nix`](../../modules/apps/stremio.nix) (Waydroid itself: [`modules/core/waydroid.nix`](../../modules/core/waydroid.nix)) |

## How it's set up

- **Kept warm.** Android starts with the desktop, so the tile opens Stremio in seconds
  instead of ~30. Idle, Android holds about 1 GB of RAM.
- **Always a fresh window.** Closing Stremio's window leaves the app running in Android with
  nowhere to draw, so the tile restarts it when no window is open and only brings it back
  when one is.
- **Remote-friendly Android** (shared with the other Android apps): LeanKey as the keyboard,
  Back on the remote's Back key or <kbd>Esc</kbd>, no navigation bar, and fixes so video
  decoding works in Waydroid.
- Turning on Stremio turns on Waydroid. It stays on while any Android app is enabled.

## First boot

Nothing to do. On the first boot with internet, Android itself (about 1 GB) downloads in the
background, then Android starts and Stremio installs itself; give it a few minutes. With the
kill switch on, the download starts once you've picked an exit node. Follow it with
`journalctl -u waydroid-init -f`.

## Troubleshooting

- **Android restarts by itself now and then:** Waydroid's display driver can deadlock
  Android when a window gets focus. A watchdog notices and restarts the session; the fix is
  in Waydroid upstream but not yet in a released image.

## Removing it

Set `nixtv.apps.stremio.enable = false`. With no Android apps left, Waydroid is turned off
too, but Android's data stays. Remove it with
`sudo rm -rf /var/lib/waydroid ~/.local/share/waydroid`.
