# Declarative partitioning for the LUKS reinstall — applied via:
#   nix run github:nix-community/disko -- --mode disko ./hosts/laptop-gaming/disko.nix
#
# Root disk is nvme1n1 (1.8T). nvme0n1 (476G) is left untouched — it's used
# as temporary backup staging before the reinstall and is not managed here.
{
  disko.devices = {
    disk = {
      main = {
        device = "/dev/nvme1n1";
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
