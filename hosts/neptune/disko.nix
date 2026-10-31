# Partition layout for neptune's system drive.
#
# Targets the drive by serial so it cannot hit the wrong disk:
#   220734800566 = healthy SN770 (was the Windows drive)
#   2152BC451902 = worn-out SN770 (old Ubuntu drive) — do NOT use
#
# btrfs + zstd compression cuts write volume; noatime avoids a write per read.
{
  disko.devices.disk.main = {
    type = "disk";
    device = "/dev/disk/by-id/nvme-WD_BLACK_SN770_2TB_220734800566";
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
        root = {
          size = "100%";
          content = {
            type = "btrfs";
            extraArgs = [ "-f" "-L" "nixos" ];
            subvolumes =
              let opts = [ "compress=zstd:1" "noatime" ];
              in {
                "@root" = { mountpoint = "/"; mountOptions = opts; };
                "@home" = { mountpoint = "/home"; mountOptions = opts; };
                "@nix" = { mountpoint = "/nix"; mountOptions = opts; };
                "@log" = { mountpoint = "/var/log"; mountOptions = opts; };
                "@docker" = { mountpoint = "/var/lib/docker"; mountOptions = opts; };
                "@snapshots" = { mountpoint = "/.snapshots"; mountOptions = opts; };
              };
          };
        };
      };
    };
  };
}
