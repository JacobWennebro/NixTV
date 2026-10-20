# PLACEHOLDER: generate this file inside your VM and put it here:
#
#   sudo nixos-generate-config --root /mnt --show-hardware-config \
#     > hosts/utm/hardware-configuration.nix
#
# This placeholder works as-is if you partition with the labels in the README
# (EFI partition labelled "BOOT", root labelled "nixos").
{ lib, ... }:

{
  boot.initrd.availableKernelModules = [
    "xhci_pci"
    "virtio_pci"
    "usbhid"
    "usb_storage"
    "sr_mod"
  ];

  fileSystems."/" = {
    device = "/dev/disk/by-label/nixos";
    fsType = "ext4";
  };

  fileSystems."/boot" = {
    device = "/dev/disk/by-label/BOOT";
    fsType = "vfat";
    options = [
      "fmask=0077"
      "dmask=0077"
    ];
  };

  swapDevices = [ ];

  nixpkgs.hostPlatform = lib.mkDefault "aarch64-linux";
}
