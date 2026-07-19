{ pkgs, inputs, ... }:
{
  imports = [
    ./hardware-configuration.nix
    ../../modules/nixos/base.nix
  ];

  networking.hostName = "laptop-light";

  # Lets wireshark capture packets without running as root (dumpcap gets
  # CAP_NET_RAW/CAP_NET_ADMIN, restricted to the wireshark group).
  programs.wireshark.enable = true;
  users.users.lmichault.extraGroups = [ "wireshark" "libvirtd" ];

  # KVM/QEMU virtualization + GUI front-end.
  virtualisation.libvirtd.enable = true;
  programs.virt-manager.enable = true;

  system.stateVersion = "24.11";
}
