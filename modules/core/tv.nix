# Living-room hardware: video decode, audio over HDMI, remotes, no sleep.
{ lib, pkgs, ... }:

let
  isx86 = pkgs.stdenv.hostPlatform.isx86_64;
in
{
  # Hardware video decoding (VA-API) for smooth 4K playback.
  hardware.graphics = {
    enable = true;
    extraPackages = lib.optionals isx86 [
      pkgs.intel-media-driver # Intel Broadwell+
      pkgs.libva-vdpau-driver
    ];
  };

  # Audio (incl. HDMI/ARC passthrough).
  services.pulseaudio.enable = false;
  security.rtkit.enable = true;
  services.pipewire = {
    enable = true;
    alsa.enable = true;
    pulse.enable = true;
  };

  # Bluetooth remotes, keyboards and gamepads.
  hardware.bluetooth = {
    enable = true;
    powerOnBoot = true;
  };
  hardware.xone.enable = isx86; # Xbox wireless controllers
  hardware.steam-hardware.enable = true; # udev rules for common gamepads

  # HDMI-CEC: control the box with the TV's own remote (needs a CEC-capable
  # port or a Pulse-Eight USB-CEC adapter). Bigscreen's remote-controllers
  # plugin uses libcec; uinput lets it inject key presses.
  hardware.uinput.enable = true;
  environment.systemPackages = [ pkgs.libcec ]; # cec-client for debugging
  services.udev.extraRules = ''
    SUBSYSTEM=="cec", GROUP="video", MODE="0660"
  '';

  # A TV box should never suspend on its own.
  systemd.targets = {
    sleep.enable = false;
    suspend.enable = false;
    hibernate.enable = false;
    hybrid-sleep.enable = false;
  };

  # mDNS so you can `ssh tv@nixos-tv.local`, and casting/discovery works.
  services.avahi = {
    enable = true;
    nssmdns4 = true;
    publish = {
      enable = true;
      addresses = true;
    };
  };
}
