# Any TV box: the host `nixtv-install` sets up. Only the generated hardware
# configuration is machine-specific; add settings for your own hardware here
# (README, "Hardware tips").
{
  imports = [ ./hardware-configuration.nix ];

  # The NixOS release this machine was first installed with (nixtv-install
  # writes it). Never change it on upgrades: it keeps old data formats working.
  system.stateVersion = "26.11";
}
