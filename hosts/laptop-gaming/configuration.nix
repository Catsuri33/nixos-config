{ pkgs, inputs, ... }:
{
  imports = [
    ./hardware-configuration.nix
    ../../modules/nixos/base.nix
    ../../modules/nixos/nvidia.nix
    ../../modules/nixos/gaming.nix
  ];

  networking.hostName = "laptop-gaming";

  services.rpcbind.enable = true;
  boot.supportedFilesystems = [ "nfs" ];

  fileSystems."/mnt/jellyfin" = {
    device = "192.168.1.152:/tank/jellyfin/media";
    fsType = "nfs";
    options = [ "nfsvers=4" "noatime" "x-systemd.automount" "noauto" "x-systemd.idle-timeout=600" ];
  };

  system.stateVersion = "24.11";
}
