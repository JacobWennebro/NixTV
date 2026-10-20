> [!WARNING]
> **NixTV is early in development and hasn't been tested thoroughly.** Most of it has only
> run in an aarch64 test VM so far: real TV hardware, x86_64 boxes and many option combinations
> are largely untested, and options may change without notice. Expect rough edges, and keep
> a way to roll back (`nixos-rebuild switch --rollback`) before relying on it.

<p align="center">
  <picture>
    <source media="(prefers-color-scheme: dark)" srcset="docs/assets/logo-dark.svg">
    <img src="docs/assets/logo-light.svg" alt="NixTV" width="270">
  </picture>
</p>

<p align="center">
  <b>A private, ad-free operating system for your living-room TV</b><br>
  Built on NixOS, KDE Plasma 6.8 (Big Screen), available for ARM and x86_64 systems
</p>

<p align="center">
  <img alt="NixOS unstable" src="https://img.shields.io/badge/NixOS-unstable-5277C3?logo=nixos&logoColor=white">
  <img alt="KDE Plasma 6.8" src="https://img.shields.io/badge/KDE_Plasma-6.8_Bigscreen-1D99F3?logo=kde&logoColor=white">
  <img alt="Wayland" src="https://img.shields.io/badge/Wayland-only-FFBC00?logo=wayland&logoColor=black">
  <img alt="x86_64 and aarch64" src="https://img.shields.io/badge/arch-x86__64_%7C_aarch64-555">
</p>

<p align="center">
  <a href="#apps">Apps</a> ·
  <a href="#install">Install</a> ·
  <a href="#configure">Configure</a> ·
  <a href="#the-kill-switch">Kill switch</a> ·
  <a href="#day-to-day">Day-to-day</a> ·
  <a href="#contributing">Contributing</a>
</p>

---

## Why NixTV

Smart TVs and streaming sticks have turned into ad platforms that spy on you. 
NixTV turns any PC into a TV box you actually own:

- **No ads, no telemetry, no account.** YouTube without ads, IPTV that never syncs to a cloud,
  and an OS that doesn't phone home.
- **Your VPN or nothing.** An optional firewall kill switch allows internet only through a
  Tailscale exit node (Mullvad works too). If the VPN drops, apps go offline instead of leaking.
- **One file decides everything.** Every app and feature is a switch in
  [`config.nix`](config.nix). Turn one off, rebuild, and it's gone: tile, icon, services and all.
- **Reproducible.** `flake.lock` pins every package, so the same repo builds the same TV
  on any matching box, and a bad update is one rollback away.
- **Made for the sofa.** It boots straight into a 10-foot interface you drive with the TV's own
  remote (HDMI-CEC), a gamepad, a Bluetooth remote or your phone.

> NixTV controls what the *box* does. The services you stream from still see what you
> watch.

## Apps

If an app you use is missing, feel free to contribute by adding it to the project. See
[Contributing](#contributing).

| App | What it is | Default |
| --- | --- | :---: |
| [**YouTube**](docs/apps/youtube.md) | Red, an ad-free YouTube client, in its TV mode | ✅ |
| [**IPTV**](docs/apps/iptv.md) | iptvs, a TV-friendly player for Xtream, Stalker and M3U sources | ✅ |
| [**Stremio**](docs/apps/stremio.md) | Stremio's Android TV app, in Waydroid | ✅ |
| [**SVT Play**](docs/apps/svtplay.md) | SVT Play's Android app, in Waydroid | ⬜ |
| [**LibreWolf**](docs/apps/librewolf.md) | The default browser, not a tile | ✅ |

Under the hood:

- **KDE Plasma 6.8 + [Plasma Bigscreen](https://invent.kde.org/plasma/plasma-bigscreen)**, logged in
  automatically, with an on-screen keyboard that appears for remotes too
- **Remote-friendly Android:** [LeanKey](https://github.com/yuliskov/LeanKeyboard) as Android's
  keyboard, Back on <kbd>Esc</kbd>, no navigation bar, and fixes for Waydroid's video codecs
- **Living-room hardware:** VA-API video decode, HDMI audio over PipeWire, Bluetooth, Xbox
  and other gamepads, HDMI-CEC, KDE Connect, never suspends
- **Remote admin:** SSH and mDNS (`ssh tv@nixos-tv.local`)

## Install

You need a UEFI PC (an old desktop, mini PC or laptop is perfect), a USB stick of 2 GB or more, an internet
connection, and about 30 minutes.

### With the NixTV installer (recommended)

1. **Download the ISO** for your CPU from the [Releases](../../releases) page: `x86_64` for
   most PCs, `aarch64` for ARM boxes, e.g. `nixtv-0.1.0-x86_64.iso`. To check it, download
   `SHA256SUMS` too and run `sha256sum -c SHA256SUMS --ignore-missing`.

   Or build it yourself on Linux with Nix: `nix build .#iso` in a clone (it ends up in `result/iso/`).
2. **Write it to a USB stick** with [Fedora Media Writer](https://flathub.org/apps/org.fedoraproject.MediaWriter),
   [balenaEtcher](https://etcher.balena.io), or `dd`, and boot the TV box from it.
3. **Get online.** A network cable works by itself; for Wi-Fi run `nmtui`.
4. **Run the installer** and answer its questions (disk, name, time zone, apps, privacy):

   ```bash
   sudo nixtv-install
   ```

   It erases the disk you pick, writes your answers to `/etc/nixos/config.nix` and installs.
   The ISO is small; everything else downloads during the install.
5. **Reboot** and remove the stick. The box starts straight into its home screen. Flatpak
   apps finish installing in the background (`journalctl -u flatpak-managed-install -f`).

To add or remove apps later, see [Configure](#configure). Putting `/etc/nixos` in git is a
good idea.

<details>
<summary><b>Installing by hand from the NixOS ISO</b></summary>

<br>

1. **Boot** the [NixOS minimal ISO](https://nixos.org/download/) on the TV box.
2. **Partition** the disk. This assumes `/dev/nvme0n1`; check yours with `lsblk`:

   ```bash
   sudo parted /dev/nvme0n1 -- mklabel gpt
   sudo parted /dev/nvme0n1 -- mkpart ESP fat32 1MiB 1GiB
   sudo parted /dev/nvme0n1 -- set 1 esp on
   sudo parted /dev/nvme0n1 -- mkpart root ext4 1GiB 100%
   sudo mkfs.fat -F 32 -n BOOT /dev/nvme0n1p1
   sudo mkfs.ext4 -L nixos /dev/nvme0n1p2
   sudo mount /dev/disk/by-label/nixos /mnt
   sudo mkdir -p /mnt/boot && sudo mount -o umask=077 /dev/disk/by-label/BOOT /mnt/boot
   ```

3. **Clone** this repo and generate the hardware config:

   ```bash
   nix-shell -p git
   git clone https://github.com/JacobWennebro/NixTV.git /mnt/etc/nixos
   sudo nixos-generate-config --root /mnt --show-hardware-config > /mnt/etc/nixos/hosts/nixtv/hardware-configuration.nix
   ```

4. **Configure** `/mnt/etc/nixos/config.nix` (host name, user, time zone, keyboard, apps; see
   [Configure](#configure)). In `hosts/nixtv/default.nix`, set `system.stateVersion` to the
   release of the NixOS ISO you booted (`nixos-version` shows it, e.g. `26.11`). Then install:

   ```bash
   sudo nixos-install --flake /mnt/etc/nixos#nixtv
   ```

5. **Set a password** for the TV user (there's no default one), then reboot:

   ```bash
   sudo nixos-enter --root /mnt -c 'passwd tv'
   ```

Commit `flake.lock` and your `hardware-configuration.nix`. From then on, the repo rebuilds
the same system on any matching box.

</details>

### First-boot steps

- **Tailscale:** log in from Trayscale. With the kill switch on, the TV's browser can't reach
  the login page yet, so open the link or QR code on your phone.
- **Apps:** check each enabled app's page in [`docs/apps/`](docs/apps/) for steps of its own.
- **Android apps:** Android (about 1 GB) downloads by itself on the first boot, then the apps
  install; this takes a few minutes. With the kill switch on, it starts once you pick an exit
  node.

<details>
<summary><b>Hardware tips</b></summary>

<br>

Put these in your host's `default.nix` (`hosts/<host>/`, or `/etc/nixos/hosts/nixtv/` after
using the installer).

**Running a laptop with its lid closed.** Closing the lid normally asks the system to
suspend. NixTV has suspend turned off, but tell it to ignore the lid so it doesn't even try:

```nix
services.logind.settings.Login = {
  HandleLidSwitch = "ignore";
  HandleLidSwitchExternalPower = "ignore";
  HandleLidSwitchDocked = "ignore";
};
```

**Intel CPUs:** `services.thermald.enable = true;` keeps fans quieter during long playback.

**Intel + NVIDIA (hybrid graphics).** NixTV runs on the Intel GPU, and nouveau powers the
NVIDIA one down. That works when the HDMI port is wired to the Intel GPU, which is usually
the case. With the TV plugged in, check:

```bash
for c in /sys/class/drm/card*-HDMI-A-*; do echo "$c: $(cat $c/status) via $(basename $(readlink -f ${c%-HDMI*}/device/driver))"; done
```

If it says `connected via nouveau` (or there's no picture), use NVIDIA's driver in PRIME
offload mode. Check both bus IDs with `lspci | grep -E "VGA|3D"` (`00:02.0` is `PCI:0:2:0`):

```nix
services.xserver.videoDrivers = [ "modesetting" "nvidia" ];
hardware.nvidia = {
  # GTX 10xx/MX 2xx (Pascal) and older: nvidiaPackages.legacy_580 with open = false.
  package = config.boot.kernelPackages.nvidiaPackages.stable;
  open = true; # RTX 20xx (Turing) and newer
  modesetting.enable = true;
  powerManagement.enable = true;
  powerManagement.finegrained = true;
  prime = {
    offload.enable = true;
    intelBusId = "PCI:0:2:0";
    nvidiaBusId = "PCI:1:0:0";
  };
};
```

This hasn't been tested on hardware yet. On other GPUs there's nothing to do: Mesa covers
AMD's video decoding, and Intel's is built in.

</details>

<details>
<summary><b>Trying it in a VM (UTM on Apple Silicon)</b></summary>

<br>

Same steps as above with the `aarch64` minimal ISO, a VirtIO disk (`/dev/vda`) and
`--flake /mnt/etc/nixos#utm`. Write the generated hardware config to
`hosts/utm/hardware-configuration.nix`. Two UTM settings matter:

- **Display → `virtio-gpu-gl-pci` (GPU Supported).** Android in Waydroid draws through a GPU
  render node (`/dev/dri/renderD128`), which only the 3D display provides.
- **Eject the ISO after installing** (drive icon in the toolbar). UTM boots the CD first.

</details>

## Configure

Everything about your TV is in one file: `/etc/nixos/config.nix` on the box (this repo's
[`config.nix`](config.nix) when installing by hand). The installer writes it from your answers;
afterwards, change it whenever you like and apply it:

```bash
sudo nixos-rebuild switch --flake /etc/nixos#nixtv
```

Turning an app off removes everything it added; turning one on installs it. A typical file:

```nix
nixtv = {
  user = "tv";
  timeZone = "Europe/Stockholm";
  onScreenKeyboard.locales = [ "en_US" ];

  apps = {
    youtube.enable = true;
    iptv.enable = true;
    stremio.enable = true;
    svtplay.enable = false;
    librewolf.enable = true;
  };

  tailscale.enable = true;
  tailscale.killswitch.enable = true;
};
```

| Option | Default | Adds |
| --- | :---: | --- |
| `nixtv.apps.<app>.enable` | see [Apps](#apps) | One switch per app; app-specific options are on its page |
| `nixtv.tailscale.enable` | ⬜ | Tailscale, Trayscale and the exit-node item |
| `nixtv.tailscale.killswitch.enable` | ⬜ | No internet except through an exit node |
| `nixtv.tailscale.killswitch.allowLan` | ✅ | Keep SSH, casting and KDE Connect working at home |
| `nixtv.sshKeys` | none | Public SSH keys that may log in as the TV user |
| `nixtv.onScreenKeyboard.locales` | `en_US` | On-screen keyboard layouts (several adds a language key) |

`hostName`, `user`, `timeZone`, `locale` and `keyboardLayout` live in the same file. Waydroid
switches itself on with the first Android app. Tiles are ordered by `nixtv.favorites.<app>.order`
(e.g. `nixtv.favorites.youtube.order = 5;`), and you can rearrange them on the TV too.

## The kill switch

With `nixtv.tailscale.killswitch.enable`, the firewall
([`modules/tailscale/killswitch.nix`](modules/tailscale/killswitch.nix)) drops every outgoing
packet except:

- traffic through `tailscale0` (your exit node or tailnet)
- Tailscale's own packets, which carry its bypass mark
- DHCP, and the local network if `allowLan` is on, **but never DNS to it**

It also covers traffic the box forwards, such as Android in Waydroid. Because it's enforced
by the firewall rather than by routing, it holds while Tailscale restarts or reconnects.
With no exit node selected, there's no internet at all, updates included, so pick one before
`nixos-rebuild` or Flatpak updates.

- **Mullvad exit nodes** appear only for devices you've added under Settings → Mullvad VPN in
  the Tailscale admin console.
- **DNS** only goes to Tailscale's `100.100.100.100` (NetworkManager doesn't hand out the
  router's). With an exit node, lookups go through it. Without one, nothing resolves. If your
  tailnet adds global nameservers, Tailscale uses those instead.
- **Check for leaks** with `sudo nft list chain inet killswitch output`; the counter shows what
  was blocked, and drops are logged as `killswitch drop:` in `journalctl -k`.

## Day-to-day

```bash
sudo nixos-rebuild switch --flake /etc/nixos#nixtv   # apply changes
nix flake update                                   # move to newer Plasma/nixpkgs, then switch
sudo nixos-rebuild switch --rollback               # undo a bad update
```

Or deploy from another computer over SSH:

```bash
nixos-rebuild switch --flake .#nixtv --target-host tv@nixos-tv.local --use-remote-sudo
```

- **Add any Flatpak:** put its Flathub ID in `services.flatpak.packages` (e.g. in `config.nix`).
- **Need the normal desktop?** Log out and pick "Plasma (Wayland)" at the login screen.

> **Why nixos-unstable?** Plasma Bigscreen returned with Plasma 6.7; NixOS 26.05 stays on 6.6
> and doesn't package it. `flake.lock` still pins the exact commit, so builds are reproducible
> until you run `nix flake update`.

<details>
<summary><b>Project layout</b></summary>

<br>

```
config.nix                   your TV: which apps and features, user, time zone
flake.nix                    inputs, hosts, and the installer ISO
iso/                         the NixTV installer ISO and `nixtv-install`
hosts/nixtv/                 any box: the host the installer sets up
hosts/utm/                   aarch64 UTM virtual machine, for trying NixTV out
modules/core/base.nix        boot, user, SSH, Nix settings
modules/core/bigscreen.nix   Plasma + Bigscreen: tiles, top row, window rules, keyboard
modules/core/flatpak.nix     Flatpak (+ refreshes Bigscreen after installs)
modules/core/waydroid.nix    Android in Waydroid (codec fixes, LeanKey, watchdog)
modules/core/tv.nix          graphics, audio, remotes, CEC, no sleep
modules/tailscale/           Tailscale, Trayscale, exit-node item, kill switch
modules/apps/                one file per app: youtube, iptv, stremio, svtplay, librewolf
docs/apps/                   one page per app
docs/assets/                 images for the docs (logo)
pkgs/iptvs/                  iptvs package (Flutter, not in nixpkgs)
assets/                      tile icons, splash logo and wallpaper, used by the build
```

To add an app, see [Contributing](#contributing).

</details>

## Contributing

Contributions are very welcome, whether that's a new app, a fix, or a report of how NixTV
runs on your hardware (see the warning at the top: real-world testing helps a lot).

- **Found a bug or tested on new hardware?** Open an issue with your box, GPU and what happened.
- **Fixes and improvements:** open a pull request. Keep changes focused, one topic per PR.

### Adding an app

Every app is one self-contained file in [`modules/apps/`](modules/apps/), behind an `enable`
option, so it's easy to add without touching the rest. For a Flathub app:

1. **Create `modules/apps/<name>.nix`.** This example adds a Flatpak as a home-screen tile:

   ```nix
   # Example App (Flatpak), as the "Example" tile.
   { config, lib, ... }:

   let
     id = "org.example.App"; # its Flathub ID
   in
   {
     options.nixtv.apps.example.enable = lib.mkEnableOption "the Example tile";

     config = lib.mkIf config.nixtv.apps.example.enable {
       services.flatpak.packages = [ id ];
       nixtv.fullscreenApps = [ id ]; # its window class (Wayland app ID)

       nixtv.favorites.example = {
         order = 50; # position in the Favorites row, lowest first
         storageId = "${id}.desktop";
         name = "Example";
         icon = id;
         desktopPath = "/var/lib/flatpak/exports/share/applications/${id}.desktop";
         entryPath = "flatpak run ${id}";
       };
     };
   }
   ```

   Anything the app needs beyond that (an icon in `assets/`, a renamed launcher, a package in
   `pkgs/`, an Android APK through `nixtv.waydroid.apks`) belongs in the same file. The
   existing modules are good templates: [`youtube.nix`](modules/apps/youtube.nix) for a
   Flatpak, [`iptv.nix`](modules/apps/iptv.nix) for a Nix package and
   [`stremio.nix`](modules/apps/stremio.nix) for an Android app.
2. **Import it** in [`modules/default.nix`](modules/default.nix).
3. **Document it:** a page in [`docs/apps/`](docs/apps/) (copy an existing one: what it is,
   its options, how it's set up, first-boot steps, known limitations), a row in the
   [Apps](#apps) table linking to it, and a line in [`config.nix`](config.nix).
4. **Check that it builds** with the app both on and off:

   ```bash
   nix eval .#nixosConfigurations.tv.config.system.build.toplevel.drvPath
   ```

   Then try it on a box or in the [test VM](#install) if you can, and say in the pull request
   what you tested.

New apps should be off by default unless they're broadly useful and work without manual steps.

### Releases

Versions follow [SemVer](https://semver.org); while NixTV is 0.x, a minor bump may change
options. Note changes under **Unreleased** in [`CHANGELOG.md`](CHANGELOG.md) as you make them,
with option changes under **Breaking**. When releasing, rename that section to the version and
date (e.g. `[0.1.0] - 2026-10-25`). Pushing a tag builds both ISOs and publishes them as a GitHub release
([`.github/workflows/release.yml`](.github/workflows/release.yml)):

```bash
git tag v0.1.0 && git push origin v0.1.0
```

To just try a build, run the Release workflow by hand from the Actions tab; the ISOs are
kept as workflow artifacts.

## Credits

NixTV stands on [NixOS](https://nixos.org), [KDE Plasma Bigscreen](https://invent.kde.org/plasma/plasma-bigscreen),
[Waydroid](https://waydro.id), [LeanKey](https://github.com/yuliskov/LeanKeyboard),
[Tailscale](https://tailscale.com), [Trayscale](https://github.com/DeedleFake/trayscale)
and [nix-flatpak](https://github.com/gmodena/nix-flatpak). The default wallpaper, Bratislava
at dusk, is by [Martin Katler](https://unsplash.com/@martinkatler) on Unsplash. The apps belong to their authors (see each app's
page); NixTV only installs them for you.

## License

NixTV's own code and documentation are licensed under the terms in [`LICENSE`](LICENSE).
That doesn't cover:

- **The default wallpaper**, `assets/wallpaper.jpg`: a photo by
  [Martin Katler](https://unsplash.com/@martinkatler), under the
  [Unsplash License](https://unsplash.com/license).
- **Third-party logos and icons** in `assets/` and the
  names of those apps and services: these are trademarks or copyrighted works of their
  owners, used only to identify the apps. NixTV isn't affiliated with or endorsed by them.
- **The software NixTV installs**, such as NixOS, KDE Plasma, Waydroid and the apps: each
  comes under its own license. The installer ISO contains free software from NixOS, built
  from the [nixpkgs](https://github.com/NixOS/nixpkgs) commit pinned in `flake.lock`; its
  source is available there.
