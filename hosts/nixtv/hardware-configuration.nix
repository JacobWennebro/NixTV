# PLACEHOLDER — `nixtv-install` (the NixTV ISO) replaces this with the file
# generated for your machine. Installing by hand, generate it yourself:
#
#   sudo nixos-generate-config --root /mnt --show-hardware-config \
#     > hosts/nixtv/hardware-configuration.nix
#
# This placeholder works as-is if you partition with the labels used in the
# installer and README (EFI partition labelled "BOOT", root labelled "nixos"), but the
# generated file also picks the right kernel modules and CPU microcode.
{ lib, modulesPath, ... }:

{
  imports = [ (modulesPath + "/installer/scan/not-detected.nix") ];

  boot.initrd.availableKernelModules = [
    "xhci_pci"
    "ahci"
    "nvme"
    "usbhid"
    "usb_storage"
    "sd_mod"
    "sdhci_pci"
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

  nixpkgs.hostPlatform = lib.mkDefault "x86_64-linux";
  hardware.cpu.intel.updateMicrocode = lib.mkDefault true;
  hardware.cpu.amd.updateMicrocode = lib.mkDefault true;
}
