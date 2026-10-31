# Hardware for neptune: MSI MS-7D25, i7-12700K, RTX 3070 Ti (3x DisplayPort),
# Intel I225-V ethernet, Intel CNVi wifi. Filesystems come from disko.nix.
#
# After installing, compare with `nixos-generate-config --show-hardware-config`
# and copy across anything missing here.
{ inputs, lib, ... }:
{
  imports = [
    inputs.nixos-hardware.nixosModules.common-cpu-intel-cpu-only
    inputs.nixos-hardware.nixosModules.common-pc
    inputs.nixos-hardware.nixosModules.common-pc-ssd
  ];

  boot.initrd.availableKernelModules = [ "nvme" "xhci_pci" "ahci" "usbhid" "usb_storage" "sd_mod" ];
  boot.kernelModules = [ "kvm-intel" ];

  hardware.enableRedistributableFirmware = true;
  hardware.cpu.intel.updateMicrocode = true;
  nixpkgs.hostPlatform = lib.mkDefault "x86_64-linux";

  # Toshiba 5 TB HDD (NTFS). Good place for bulky scratch/output.
  fileSystems."/mnt/toshiba" = {
    device = "/dev/disk/by-label/ToshHDD";
    fsType = "ntfs3";
    options = [ "uid=1000" "gid=100" "nofail" "noatime" "x-systemd.automount" ];
  };
}
