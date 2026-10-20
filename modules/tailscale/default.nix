# Tailscale VPN, controlled from the TV with Trayscale (a Flatpak GUI that
# talks to this daemon), plus an exit-node item in the home screen's top row.
# Its tooltip is the exit node's name; it's dimmed with no exit node (the
# kill switch, ./killswitch.nix, then leaves apps offline). Selecting it opens
# Trayscale to change the exit node.
{ config, lib, pkgs, ... }:

let
  cfg = config.nixtv.tailscale;

  # assets/tailscale.svg as a recolourable icon: KDE draws an SVG with this
  # stylesheet class in the theme's text colour, like the row's other icons.
  # A wider viewBox adds the margin KDE's icons have (the logo is drawn edge
  # to edge), so it matches their size.
  icon = pkgs.runCommand "nixtv-tailscale-icon" { } ''
    mkdir -p $out/share/icons/hicolor/scalable/apps
    sed -e 's|<path |<style id="current-color-scheme" type="text/css">.ColorScheme-Text { color:#232629; }</style><path class="ColorScheme-Text" fill="currentColor" |' \
      -e 's|viewBox="0 0 24 24"|viewBox="-3 -3 30 30"|' \
      ${../../assets/tailscale.svg} > $out/share/icons/hicolor/scalable/apps/nixtv_tailscale.svg
    grep -q 'viewBox="-3 -3 30 30"' $out/share/icons/hicolor/scalable/apps/nixtv_tailscale.svg
    grep -q ColorScheme-Text $out/share/icons/hicolor/scalable/apps/nixtv_tailscale.svg
  '';

  # Open Trayscale in front. When it's already running in the background, a
  # second launch only asks it to show its window, and on Wayland KWin
  # leaves that window behind the home screen (no activation token), so
  # raise it explicitly.
  openTrayscale = pkgs.writeShellApplication {
    name = "nixtv-open-trayscale";
    runtimeInputs = [
      pkgs.flatpak
      pkgs.kdotool
      pkgs.gnugrep
      pkgs.coreutils
      pkgs.util-linux
    ];
    text = ''
      setsid flatpak run dev.deedles.Trayscale >/dev/null 2>&1 &
      for _ in $(seq 1 20); do
        if win=$(kdotool search --class '^dev\.deedles\.Trayscale$' 2>/dev/null | grep -m1 .); then
          kdotool windowactivate "$win"
          exit 0
        fi
        sleep 0.5
      done
    '';
  };

  indicator = pkgs.writeText "Tailscale.qml" ''
    import QtQuick
    import org.kde.plasma.plasma5support as P5Support

    AbstractIndicator {
        id: tailscaleIndicator
        property string exitNode: ""

        icon.name: "nixtv_tailscale"
        text: exitNode || i18n("No exit node")
        opacity: exitNode ? 1 : 0.4

        // `tailscale status` every 5 s; the exit node is the peer marked
        // ExitNode. Named like Trayscale does: "City, Country" for location
        // nodes (Mullvad), otherwise the host name.
        P5Support.DataSource {
            engine: "executable"
            interval: 5000
            connectedSources: [ "${config.services.tailscale.package}/bin/tailscale status --json" ]
            onNewData: (source, data) => {
                let name = "";
                try {
                    const peers = JSON.parse(data["stdout"]).Peer || {};
                    for (const id in peers) {
                        const p = peers[id];
                        if (p.ExitNode) {
                            name = p.Location ? p.Location.City + ", " + p.Location.Country : p.HostName;
                        }
                    }
                } catch (e) {}
                tailscaleIndicator.exitNode = name;
            }
        }

        P5Support.DataSource {
            id: launcher
            engine: "executable"
            onNewData: (source) => disconnectSource(source)
        }

        onClicked: launcher.connectSource("${openTrayscale}/bin/nixtv-open-trayscale")
    }
  '';
in
{
  options.nixtv.tailscale.enable = lib.mkEnableOption "Tailscale, with Trayscale and an exit-node item on the home screen";

  config = lib.mkIf cfg.enable {
    services.tailscale = {
      enable = true;
      openFirewall = true; # direct (non-relayed) connections

      # Let the TV user connect/disconnect from Trayscale without root.
      extraSetFlags = [ "--operator=${config.nixtv.user}" ];
    };

    # tailscaled-set applies extraSetFlags once at boot. Keeping it "active"
    # makes nixos-rebuild switch re-run it when the flags change.
    systemd.services.tailscaled-set.serviceConfig.RemainAfterExit = true;

    services.flatpak.packages = [ "dev.deedles.Trayscale" ];
    nixtv.fullscreenApps = [ "dev.deedles.Trayscale" ];

    environment.systemPackages = [ icon ];
    nixtv.bigscreen.indicators = [
      {
        name = "Tailscale";
        source = indicator;
      }
    ];
  };
}
