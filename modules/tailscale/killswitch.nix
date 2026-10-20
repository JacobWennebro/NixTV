# Kill switch: apps only reach the internet through a Tailscale exit node.
# Covers the host's own traffic (output) and traffic it forwards, such as
# Android in Waydroid (forward).
#
# Enforced by the firewall rather than by routing, so it also holds while
# tailscaled restarts, reconnects, or when no exit node is selected:
#   - leaving via tailscale0 is allowed (exit node or tailnet peers);
#   - tailscaled's own packets (WireGuard, DERP relays, control plane) carry
#     Tailscale's bypass fwmark (0x80000) and are allowed;
#   - DHCP/IPv6 neighbour discovery are allowed so the link comes up;
#   - with allowLan, the local network is allowed, except DNS;
#   - everything else is dropped.
#
# With no exit node selected, apps have no internet. Only tailscaled does
# (so you can log in and pick one in Trayscale). That includes system
# updates: select an exit node before `nixos-rebuild` or Flatpak updates.
{ config, lib, ... }:

let
  cfg = config.nixtv.tailscale.killswitch;
  inherit (cfg) allowLan;

  lan4 = [
    "10.0.0.0/8"
    "172.16.0.0/12"
    "192.168.0.0/16"
    "169.254.0.0/16"
    "224.0.0.0/4"
    "255.255.255.255"
  ];
  lan6 = [
    "fe80::/10"
    "fc00::/7"
    "ff00::/8"
  ];
in
{
  options.nixtv.tailscale.killswitch = {
    enable = lib.mkEnableOption "the kill switch: no internet except through a Tailscale exit node";
    allowLan = lib.mkOption {
      type = lib.types.bool;
      default = true;
      description = ''
        Keep SSH, casting, KDE Connect etc. working on the home network. DNS
        to the LAN is still blocked: it would go to the router and on to the ISP.
      '';
    };
  };

  config = lib.mkIf cfg.enable {
    assertions = [
      {
        assertion = config.nixtv.tailscale.enable;
        message = "nixtv.tailscale.killswitch needs nixtv.tailscale.enable: the exit node is the only way out.";
      }
    ];

    networking.nftables.enable = true;

    networking.nftables.tables.killswitch = {
      family = "inet";
      content = ''
        chain output {
          type filter hook output priority filter; policy drop;

          oifname "lo" accept
          meta mark & 0x00ff0000 == 0x00080000 accept comment "tailscaled's own traffic"
          oifname "tailscale0" accept comment "exit node / tailnet"

          udp sport 68 udp dport 67 accept comment "DHCPv4"
          udp sport 546 udp dport 547 accept comment "DHCPv6"
          icmpv6 type { nd-router-solicit, nd-neighbor-solicit, nd-neighbor-advert, mld2-listener-report } accept
          ${lib.optionalString allowLan ''
            meta l4proto { tcp, udp } th dport { 53, 853 } drop comment "no DNS outside Tailscale"
            ip daddr { ${lib.concatStringsSep ", " lan4} } accept comment "LAN"
            ip6 daddr { ${lib.concatStringsSep ", " lan6} } accept comment "LAN"
          ''}
          limit rate 6/minute log prefix "killswitch drop: "
          counter comment "dropped by kill switch"
        }

        # Traffic the host routes for others, e.g. Android in Waydroid (NATed
        # from waydroid0), never passes the output chain: same rules here.
        chain forward {
          type filter hook forward priority filter; policy drop;

          ct state established,related accept
          oifname "tailscale0" accept comment "exit node / tailnet"
          ${lib.optionalString allowLan ''
            meta l4proto { tcp, udp } th dport { 53, 853 } drop comment "no DNS outside Tailscale"
            ip daddr { ${lib.concatStringsSep ", " lan4} } accept comment "LAN"
            ip6 daddr { ${lib.concatStringsSep ", " lan6} } accept comment "LAN"
          ''}
          limit rate 6/minute log prefix "killswitch fwd drop: "
          counter comment "forwarding dropped by kill switch"
        }
      '';
    };

    # With an exit node on, Tailscale would also route LAN traffic through it.
    services.tailscale.extraSetFlags = lib.optional allowLan "--exit-node-allow-lan-access=true";

    # No DNS servers outside Tailscale. Otherwise NetworkManager hands the
    # router's DNS to openresolv, and with no exit node selected Tailscale's
    # resolver (100.100.100.100) forwards lookups there with its bypass mark,
    # leaking names past the firewall. With an exit node, Tailscale sends DNS
    # through the exit node; tailscaled finds its control servers without
    # system DNS.
    networking.networkmanager.dns = "none";
  };
}
