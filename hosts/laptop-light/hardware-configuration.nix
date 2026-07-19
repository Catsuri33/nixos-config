# Generate with: nixos-generate-config --show-hardware-config
{ ... }:
{
  boot.initrd.availableKernelModules = [];
  boot.kernelModules = [];
}
