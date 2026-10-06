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
    # "latest" branch rather than "stable": currently 615.71.09 against
    # 595.104.02 on stable. Deliberate choice to track the newest driver;
    # if a release regresses (Wayland/Hyprland sessions are the usual
    # casualty), fall back to .stable here — nothing else depends on it.
    package = config.boot.kernelPackages.nvidiaPackages.latest;
  };

  environment.systemPackages = with pkgs; [
    nvtopPackages.nvidia
  ];
}
