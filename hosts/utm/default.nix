# aarch64 host for a UTM (QEMU) virtual machine on Apple Silicon: to try
# NixTV, or work on it, without a spare PC. README, "Trying it in a VM".
{ config, lib, pkgs, modulesPath, ... }:

{
  imports = [
    (modulesPath + "/profiles/qemu-guest.nix")
    ./hardware-configuration.nix
  ];

  # Its own name, so it doesn't clash with a real TV box on the same network.
  networking.hostName = lib.mkForce "${config.nixtv.hostName}-vm";

  # Clipboard sharing and dynamic resolution in the UTM window: the system
  # daemon talks to UTM over the SPICE virtio port...
  services.spice-vdagentd.enable = true;
  services.qemuGuest.enable = true;

  # UTM's virgl GPU only offers desktop OpenGL 2.1, too old for GTK 3's GL
  # context on Wayland, so Flutter apps (iptvs) never map a window. GLES works.
  environment.sessionVariables.GDK_GL = "gles";

  # ...and a per-session agent talks to the desktop. Upstream ships it as an
  # autostart entry marked X-systemd-skip, which Plasma 6 (systemd-managed
  # autostart) never starts, so run it as a user service instead. It's a GTK3
  # X11 client; KWin syncs the Xwayland clipboard with Wayland apps.
  systemd.user.services.spice-vdagent = {
    description = "SPICE guest session agent (clipboard)";
    wantedBy = [ "graphical-session.target" ];
    partOf = [ "graphical-session.target" ];
    after = [ "graphical-session.target" ];
    serviceConfig = {
      ExecStart = "${pkgs.spice-vdagent}/bin/spice-vdagent --foreground";
      Restart = "on-failure";
      RestartSec = 5;
      # The agent also copies the SPICE client's volume onto ALSA's Master
      # control. UTM's QEMU backend plays sound via macOS, not SPICE, so it
      # reports "muted, 0 %" and every login muted the VM. Point the agent's
      # ALSA "default" control at a card that doesn't exist: the volume sync
      # fails harmlessly ("can't get default alsa mixer"), clipboard still works.
      Environment = "ALSA_CONFIG_PATH=${pkgs.writeText "vdagent-no-mixer.conf" ''
        ctl.!default { type hw card 99 }
      ''}";
    };
  };

  # The NixOS release this VM was first installed with. Never change it on
  # upgrades: it keeps old data formats working.
  system.stateVersion = "26.11";
}
