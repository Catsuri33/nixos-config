{ pkgs, ... }:
{
  # Latest kernel required for NTSync (improves Windows game compatibility)
  boot.kernelPackages = pkgs.linuxPackages_latest;

  programs.steam = {
    enable = true;
    remotePlay.openFirewall = true;
    gamescopeSession.enable = true;
  };

  environment.systemPackages = with pkgs; [
    protonplus
  ];
}
