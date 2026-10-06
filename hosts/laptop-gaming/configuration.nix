{ pkgs, inputs, ... }:
{
  imports = [
    ./hardware-configuration.nix
    ../../modules/nixos/base.nix
    ../../modules/nixos/nvidia.nix
    ../../modules/nixos/gaming.nix
    ../../modules/nixos/thermal.nix
    ../../modules/nixos/power-saving.nix
  ];

  networking.hostName = "laptop-gaming";

  system.stateVersion = "24.11";
}
