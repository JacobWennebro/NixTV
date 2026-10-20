# The NixTV installer ISO: NixOS's minimal installer plus this repo and
# `nixtv-install`, which partitions a disk, asks a few questions (user, time
# zone, apps) and installs. Lean: packages are downloaded during the install,
# so it needs internet.
#
#   nix build .#iso   # for this machine's CPU; the ISO ends up in result/iso/
{
  config,
  lib,
  pkgs,
  modulesPath,
  self,
  ...
}:

let
  install = pkgs.writeShellApplication {
    name = "nixtv-install";
    runtimeInputs = with pkgs; [
      coreutils
      curl
      dosfstools
      e2fsprogs
      gawk
      gnugrep
      gnused
      nixos-install-tools
      parted
      systemd
      util-linux
    ];
    runtimeEnv = {
      NIXTV_SRC = "${self}";
      NIXOS_RELEASE = config.system.nixos.release; # the installed system's stateVersion
      ZONEINFO = "${pkgs.tzdata}/share/zoneinfo";
    };
    text = builtins.readFile ./nixtv-install.sh;
  };
in
{
  imports = [ (modulesPath + "/installer/cd-dvd/installation-cd-minimal.nix") ];

  image.baseName = lib.mkForce "nixtv-${self.shortRev or "dirty"}-${pkgs.stdenv.hostPlatform.system}";
  isoImage.volumeID = lib.mkForce "NIXTV";

  environment.systemPackages = [ install ];

  # Wi-Fi from `nmtui` instead of wpa_supplicant by hand.
  networking.networkmanager.enable = true;
  networking.wireless.enable = lib.mkForce false;

  nix.settings.experimental-features = [
    "nix-command"
    "flakes"
  ];

  # Same kernel as the installed system, for the same hardware support.
  boot.kernelPackages = pkgs.linuxPackages_latest;

  services.getty.helpLine = lib.mkForce ''

    Welcome to the NixTV installer.

    1. Connect to the internet: wired works by itself; for Wi-Fi run `nmtui`.
    2. Run `sudo nixtv-install` and answer a few questions.

    It erases the disk you pick. The README: less ${self}/README.md
  '';
}
