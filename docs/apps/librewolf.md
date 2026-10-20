# LibreWolf

[LibreWolf](https://librewolf.net), a privacy-focused Firefox, as the **default browser**.
It's not a tile: press <kbd>Meta</kbd>+<kbd>S</kbd> to open it.

| | |
| --- | --- |
| Option | `nixtv.apps.librewolf.enable` (default: on) |
| Source | Flathub, `io.gitlab.librewolf-community` |
| Module | [`modules/apps/librewolf.nix`](../../modules/apps/librewolf.nix) |

## How it's set up

- **Default for links** from any app (web pages and `http`/`https` links).
- **KDE's browser setting** points at LibreWolf too. Bigscreen otherwise sets it to its own
  Aura browser, which isn't installed.
