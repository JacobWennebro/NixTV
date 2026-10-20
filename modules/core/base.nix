# Boot, the TV user, SSH and Nix settings. The nixtv options here are the
# machine's basics (set in config.nix).
{ config, lib, pkgs, ... }:

let
  cfg = config.nixtv;
in
{
  options.nixtv = {
    hostName = lib.mkOption {
      type = lib.types.str;
      default = "nixos-tv";
      description = "Host name (also its mDNS name, <hostName>.local).";
    };
    user = lib.mkOption {
      type = lib.types.str;
      default = "tv";
      description = "The user the TV logs in as.";
    };
    timeZone = lib.mkOption {
      type = lib.types.str;
      default = "UTC";
      example = "Europe/Stockholm";
      description = "Time zone.";
    };
    locale = lib.mkOption {
      type = lib.types.str;
      default = "en_US.UTF-8";
      description = "System language and formats.";
    };
    keyboardLayout = lib.mkOption {
      type = lib.types.str;
      default = "us";
      description = "Layout of a physical keyboard (the on-screen one: nixtv.onScreenKeyboard).";
    };
    sshKeys = lib.mkOption {
      type = lib.types.listOf lib.types.str;
      default = [ ];
      example = [ "ssh-ed25519 AAAA... you@computer" ];
      description = "Public SSH keys that may log in as the TV user.";
    };
  };

  config = {
    # --- Boot -----------------------------------------------------------------
    boot.loader.systemd-boot.enable = true;
    boot.loader.systemd-boot.configurationLimit = 10;
    boot.loader.efi.canTouchEfiVariables = true;
    boot.loader.timeout = 1;
    boot.kernelPackages = pkgs.linuxPackages_latest;

    # Quiet, graphical boot straight into the TV UI.
    boot.plymouth.enable = true;
    boot.consoleLogLevel = 3;
    boot.initrd.verbose = false;
    boot.kernelParams = [
      "quiet"
      "splash"
      "loglevel=3"
      "rd.udev.log_level=3"
      "udev.log_priority=3"
    ];

    # --- System basics ------------------------------------------------------
    networking.hostName = cfg.hostName;
    networking.networkmanager.enable = true;

    time.timeZone = cfg.timeZone;
    i18n.defaultLocale = cfg.locale;
    services.xserver.xkb.layout = cfg.keyboardLayout;

    hardware.enableRedistributableFirmware = true;

    users.users.${cfg.user} = {
      isNormalUser = true;
      description = "TV";
      # No default password: autologin needs none. Until one is set with
      # `passwd` (nixtv-install asks for it), nobody can log in with a password,
      # over SSH or otherwise; keys in nixtv.sshKeys still work.
      extraGroups = [
        "wheel"
        "networkmanager"
        "video"
        "audio"
        "input"
        "dialout" # USB HDMI-CEC adapters (Pulse-Eight) show up as ttyACM*
        "uinput" # CEC/gamepad remotes injecting key presses
      ];
      openssh.authorizedKeys.keys = cfg.sshKeys;
    };

    # Remote management from another computer (TVs rarely have a keyboard nearby).
    services.openssh = {
      enable = true;
      settings.PermitRootLogin = "no";
    };

    # --- Nix ------------------------------------------------------------------
    nix.settings = {
      experimental-features = [
        "nix-command"
        "flakes"
      ];
      auto-optimise-store = true;
      trusted-users = [ "@wheel" ];
    };
    nix.gc = {
      automatic = true;
      dates = "weekly";
      options = "--delete-older-than 14d";
    };
    nixpkgs.config.allowUnfree = true;

    environment.systemPackages = with pkgs; [
      git
      vim
    ];
  };
}
