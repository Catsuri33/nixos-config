{ pkgs, inputs, ... }:
{
  imports = [
    ./hardware-configuration.nix
    ../../modules/nixos/base.nix
    ../../modules/nixos/nvidia.nix
    ../../modules/nixos/gaming.nix
  ];

  networking.hostName = "desktop-gaming";

  # Steam Remote Play ports, on this stationary host only: on the gaming
  # laptop they'd be open on every network it joins, public Wi-Fi included.
  programs.steam.remotePlay.openFirewall = true;

  system.stateVersion = "24.11";
}
