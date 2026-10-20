# Flatpak with declaratively managed apps from Flathub (via nix-flatpak).
# App modules add their app IDs to services.flatpak.packages; those are
# installed on `nixos-rebuild switch`, and apps removed from the list are
# uninstalled.
{ pkgs, config, ... }:

let
  appsDir = "/var/lib/flatpak/exports/share/applications";
  snapshot = "/run/flatpak-managed-apps.before";

  # Bigscreen reads its app list once, when the shell starts. On first boot the
  # install finishes after autologin, so the new apps don't show up until the
  # shell restarts. Restart it, but only when the set of apps actually changed.
  refreshBigscreen = pkgs.writeShellScript "flatpak-refresh-bigscreen" ''
    ls ${appsDir} > ${snapshot}.after 2>/dev/null || true
    if ! ${pkgs.diffutils}/bin/cmp -s ${snapshot} ${snapshot}.after; then
      ${pkgs.systemd}/bin/systemctl --user --machine=${config.nixtv.user}@ \
        try-restart plasma-plasmashell.service || true
    fi
    rm -f ${snapshot} ${snapshot}.after
  '';
in
{
  services.flatpak = {
    enable = true; # Flathub is the default remote.
    uninstallUnmanaged = false; # leave apps installed by hand alone
    update.auto = {
      enable = true;
      onCalendar = "weekly";
    };
  };

  systemd.services.flatpak-managed-install.serviceConfig = {
    ExecStartPre = [ "${pkgs.bash}/bin/sh -c 'ls ${appsDir} > ${snapshot} 2>/dev/null || true'" ];
    ExecStartPost = [ "${refreshBigscreen}" ];
  };
}
