# Declarative partitioning — applied via:
#   nix run github:nix-community/disko -- --mode disko ./hosts/desktop-gaming/disko.nix
#
# WHOLE DISK WILL BE WIPED. Check the real device name from the live ISO
# first (`lsblk`) and adjust `device` below — this is a fresh install, no
# data to preserve, so the placeholder hasn't been verified against real
# hardware yet.
{
  disko.devices = {
    disk = {
      main = {
        device = "/dev/nvme0n1"; # adjust to match `lsblk` output before running
        type = "disk";
        content = {
          type = "gpt";
          partitions = {
            ESP = {
              size = "1G";
              type = "EF00";
              content = {
                type = "filesystem";
                format = "vfat";
                mountpoint = "/boot";
                mountOptions = [ "umask=0077" ];
              };
            };
            luks = {
              size = "100%";
              content = {
                type = "luks";
                name = "cryptroot";
                settings.allowDiscards = true;
                content = {
                  type = "filesystem";
                  format = "ext4";
                  mountpoint = "/";
                };
              };
            };
          };
        };
      };
    };
  };
}
