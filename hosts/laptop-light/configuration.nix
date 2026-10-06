{ pkgs, inputs, ... }:
{
  imports = [
    ./hardware-configuration.nix
    ../../modules/nixos/base.nix
    ../../modules/nixos/power-saving.nix
  ];

  networking.hostName = "laptop-light";
  hardware.enableRedistributableFirmware = true;

  # Lets wireshark capture packets without running as root (dumpcap gets
  # CAP_NET_RAW/CAP_NET_ADMIN, restricted to the wireshark group).
  programs.wireshark.enable = true;
  users.users.lmichault.extraGroups = [ "wireshark" "libvirtd" ];

  # KVM/QEMU virtualization + GUI front-end.
  virtualisation.libvirtd.enable = true;
  programs.virt-manager.enable = true;

  # Forward DNS (port 53) from this host to the "debian13" libvirt VM
  # (192.168.122.117 on the NAT'd virbr0 network), so it can act as a
  # colleague-facing bind9 master/slave regardless of which physical
  # interface this laptop is currently using. No -i filter naming a
  # specific external interface: the source interface changes (wifi/wired)
  # depending on where the laptop is plugged in, and restricting to one
  # name would silently break DNS forwarding on every network switch.
  #
  # `! -i virbr0` IS required though: without it this rule also matches
  # port-53 packets arriving from the VM itself (its own outbound DNS
  # queries get routed through PREROUTING on the host), silently DNAT'ing
  # them back to the VM instead of letting them leave. That broke the
  # VM's own DNS resolution (recursive lookups, zone transfers to the
  # colleague's server) until this exclusion was added.
  networking.firewall.extraCommands = ''
    iptables -t nat -A PREROUTING ! -i virbr0 -p tcp --dport 53 -j DNAT --to-destination 192.168.122.117:53
    iptables -t nat -A PREROUTING ! -i virbr0 -p udp --dport 53 -j DNAT --to-destination 192.168.122.117:53

    # Hairpin so `dig @<this-host-LAN-IP>` also works when run FROM this
    # laptop itself: locally-generated packets destined to our own address
    # never traverse PREROUTING (they go straight to OUTPUT), so the
    # PREROUTING DNAT above only ever catches traffic from other hosts.
    # 10.112.0.138 is the current DHCP lease on the campus/LAN interface;
    # this is a manual testing convenience, not the colleague-facing path
    # (that one already works via PREROUTING), so it's fine if it goes
    # stale when the lease/interface changes.
    iptables -t nat -A OUTPUT -d 10.112.0.138 -p tcp --dport 53 -j DNAT --to-destination 192.168.122.117:53
    iptables -t nat -A OUTPUT -d 10.112.0.138 -p udp --dport 53 -j DNAT --to-destination 192.168.122.117:53
  '';
  networking.firewall.extraStopCommands = ''
    iptables -t nat -D PREROUTING ! -i virbr0 -p tcp --dport 53 -j DNAT --to-destination 192.168.122.117:53 || true
    iptables -t nat -D PREROUTING ! -i virbr0 -p udp --dport 53 -j DNAT --to-destination 192.168.122.117:53 || true
    iptables -t nat -D OUTPUT -d 10.112.0.138 -p tcp --dport 53 -j DNAT --to-destination 192.168.122.117:53 || true
    iptables -t nat -D OUTPUT -d 10.112.0.138 -p udp --dport 53 -j DNAT --to-destination 192.168.122.117:53 || true
  '';

  # The FORWARD-chain ACCEPT for port 53 to the VM can't live in
  # extraCommands above: firewall.service runs at sysinit.target, before
  # libvirtd/the "default" network starts, so an `iptables -I FORWARD 1`
  # done there gets pushed *below* LIBVIRT_FWI as soon as libvirt inserts
  # its own chain jumps on network start. LIBVIRT_FWI REJECTs (icmp
  # port-unreachable / tcp-reset - i.e. "connection refused") any new
  # inbound connection to the NAT'd VM subnet by default, which is exactly
  # what broke the colleague's dig/AXFR to 10.112.0.138 despite the DNAT
  # rule and the VM's bind9 both working fine. A libvirt network hook runs
  # right after libvirt builds its chains for the "default" network, so
  # inserting here guarantees we land on top of LIBVIRT_FWI every time,
  # regardless of libvirtd/firewall.service start order.
  virtualisation.libvirtd.hooks.network."10-dns-forward" = pkgs.writeShellScript "libvirt-network-dns-forward-hook" ''
    #!/bin/sh
    # libvirt calls network hooks as: $0 <network-name> <operation> <sub-op> <extra>
    # https://libvirt.org/hooks.html#network
    [ "$1" = "default" ] || exit 0

    case "$2" in
      started)
        # Always delete-then-insert rather than check-then-insert: `-C`
        # only checks whether a matching rule exists *anywhere* in the
        # chain, not at position 1, so it would wrongly consider the job
        # done if a stale copy were sitting below LIBVIRT_FWI already.
        for proto in tcp udp; do
          ${pkgs.iptables}/bin/iptables -D FORWARD -p "$proto" -d 192.168.122.117 --dport 53 -j ACCEPT 2>/dev/null || true
          ${pkgs.iptables}/bin/iptables -I FORWARD 1 -p "$proto" -d 192.168.122.117 --dport 53 -j ACCEPT
        done
        ;;
      stopped)
        for proto in tcp udp; do
          ${pkgs.iptables}/bin/iptables -D FORWARD -p "$proto" -d 192.168.122.117 --dport 53 -j ACCEPT 2>/dev/null || true
        done
        ;;
    esac
  '';

  programs.steam.enable = true;

  system.stateVersion = "24.11";
}
