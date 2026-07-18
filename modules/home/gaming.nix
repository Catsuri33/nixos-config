{ pkgs, ... }:
{
  home.packages = with pkgs; [
    heroic
    mangohud
    gamemode
    wineWow64Packages.staging
    winetricks
    protontricks
    dxvk
    qbittorrent
  ];
}
