# IPTV (iptvs)

[iptvs](https://github.com/GCHOfficial/iptvs) is an IPTV player with a TV-friendly interface
for Xtream, Stalker and M3U sources. NixTV builds it from source and shows it as the **IPTV**
tile.

| | |
| --- | --- |
| Option | `nixtv.apps.iptv.enable` (default: on) |
| Source | built from source, [`pkgs/iptvs/`](../../pkgs/iptvs/package.nix) (not in nixpkgs) |
| Module | [`modules/apps/iptv.nix`](../../modules/apps/iptv.nix) |

## How it's set up

- **Built from source.** Upstream's Linux release is an x86_64-only AppImage, so the package
  builds the Flutter app itself, for x86_64 and aarch64. The first build takes a while.
- **Fully offline.** Cloud sync is only compiled in when Supabase keys are passed at build
  time, so it's left out. Its self-updater only works from an AppImage, so it stays idle;
  updates come with NixTV.
- **Video** plays embedded (libmpv through media_kit), no separate mpv needed.
- **Renamed launcher** "IPTV" with its own icon (`assets/iptv.svg`), without rebuilding the app.

## First boot

Open the tile and add your sources (Xtream, Stalker or an M3U playlist) inside the app.

## Troubleshooting

- **No window in a VM:** Flutter apps need OpenGL ES on UTM's virtual GPU. The `utm` host
  sets `GDK_GL=gles` for this; do the same on other VMs with old desktop OpenGL.
