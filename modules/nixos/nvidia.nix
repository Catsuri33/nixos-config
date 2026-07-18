{ config, pkgs, ... }:
{
  hardware.graphics = {
    enable = true;
    enable32Bit = true;
  };

  services.xserver.videoDrivers = [ "nvidia" ];

  hardware.nvidia = {
    modesetting.enable = true;
    # Open-source kernel modules: needed for Secure Boot (unsigned
    # proprietary blobs won't load under lockdown), confirmed supported on
    # laptop-gaming's RTX 3050 Ti (Ampere/GA107, Turing+). Check the GPU
    # generation on any new host before relying on this.
    open = true;
    nvidiaSettings = true;
    package = config.boot.kernelPackages.nvidiaPackages.stable;
  };

  environment.systemPackages = with pkgs; [
    nvtopPackages.nvidia
  ];
}
