# Changelog

All notable changes to NixTV. Versions follow [Semantic Versioning](https://semver.org): while
NixTV is 0.x, a minor version may change or remove options. Each release lists what to change
in your `config.nix` under **Breaking**.

## [0.1.0] - unreleased

The first release. NixTV is early in development and hasn't been tested thoroughly.

### Added

- Plasma Bigscreen as the TV interface, logged in automatically, with an on-screen keyboard
  that works with remotes.
- A NixTV login splash: the logo pulsing on navy while the home screen loads.
- Apps, each with its own switch (`nixtv.apps.<app>.enable`) and page in `docs/apps/`:
  YouTube (Red), IPTV (iptvs), Stremio and SVT Play (Android apps in Waydroid), and
  LibreWolf as the default browser.
- Tailscale with Trayscale and an exit-node item on the home screen (`nixtv.tailscale`), and
  a kill switch that allows internet only through an exit node (`nixtv.tailscale.killswitch`).
- `config.nix` as the one place to choose apps and features.
- Android for the Android apps downloads by itself on the first boot (`waydroid-init`).
- The NixTV installer ISO (x86_64 and aarch64) with `nixtv-install`, a guided installer.
- Hosts: `nixtv` for any machine, `utm` for a UTM virtual machine.
- TV hardware support: VA-API video decoding, HDMI audio, Bluetooth, gamepads, HDMI-CEC,
  KDE Connect, no suspend.
