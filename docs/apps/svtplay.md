# SVT Play

SVT Play's **Android app**, running in [Waydroid](https://waydro.id), as the **SVT Play**
tile. It's off by default: it needs a one-time manual download, and most of it only plays
from Sweden.

| | |
| --- | --- |
| Option | `nixtv.apps.svtplay.enable` (default: off) |
| Source | the universal APK bundle from [APKMirror](https://www.apkmirror.com/apk/sveriges-television-ab/svt-play/) |
| Module | [`modules/apps/svtplay.nix`](../../modules/apps/svtplay.nix) (Waydroid itself: [`modules/core/waydroid.nix`](../../modules/core/waydroid.nix)) |

> **Terms of use.** NixTV doesn't include or distribute SVT Play: you download the app
> yourself, and the build patches your copy on your own machine. Using a modified app may go
> against SVT's terms of use, and following them is up to you. NixTV isn't affiliated with SVT.

## What plays

- **SVT's own programmes** play.
- **Bought-in films and series protected by Widevine DRM** (a few percent of the catalogue)
  fail with a licence error: Waydroid has no Widevine.
- **Most of the catalogue is only shown from Sweden,** so use a Swedish exit node.

## Getting the app

APKMirror sits behind a bot check, so Nix can't download the app itself. Do it once per
machine, either way:

- **By hand.** The first build stops with the exact steps: download the bundle in a browser,
  rename it, and add it to the Nix store with `nix-store --add-fixed sha256 svtplay-<version>.apkm`.
- **From your own copy.** Serve the file somewhere you control (for example on your tailnet)
  and set `nixtv.apps.svtplay.apkUrl`. Keep it private: it's SVT's app. The build checks the
  file against a pinned hash, so it has to be exactly the version the module expects.

Android itself downloads on the first boot (see [Stremio's first boot](stremio.md#first-boot)),
then SVT Play installs itself.

## How it's set up

- **TV interface.** The app only shows its TV interface when Android reports a television,
  and making Waydroid do that crashes Android's UI. So the build patches the app to always
  pick its TV interface.
- **Signed per machine.** A patched app needs a new signature. Each machine signs it with its
  own key, made on the first install and kept in `/var/lib/nixtv-svtplay` (not the
  world-readable Nix store), so later versions update in place. If the app was installed
  with another signature (SVT's original, or a lost key), it's replaced, which resets the
  app's settings.
- **Installs itself** as Android starts, and restarts when its window was closed, like Stremio.
