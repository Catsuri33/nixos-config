{ pkgs, ... }:
{
  # Lighter hardened_malloc variant: the full "graphene-hardened" default
  # (modules/nixos/base.nix) has a real perf cost that isn't worth it for
  # gaming workloads.
  environment.memoryAllocator.provider = "graphene-hardened-light";

  programs.steam = {
    enable = true;
    remotePlay.openFirewall = true;
    gamescopeSession.enable = true;
  };

  environment.systemPackages = with pkgs; [
    protonplus
  ];
}
