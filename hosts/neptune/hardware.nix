# Hardware for neptune: MSI MS-7D25, i7-12700K, RTX 3070 Ti (3x DisplayPort),
# Intel I225-V ethernet, Intel CNVi wifi. Filesystems come from disko.nix.
#
# After installing, compare with `nixos-generate-config --show-hardware-config`
# and copy across anything missing here.
{ inputs, config, lib, ... }:
{
  imports = [
    inputs.nixos-hardware.nixosModules.common-cpu-intel-cpu-only
    inputs.nixos-hardware.nixosModules.common-pc
    inputs.nixos-hardware.nixosModules.common-pc-ssd
  ];

  boot.initrd.availableKernelModules = [ "nvme" "xhci_pci" "ahci" "usbhid" "usb_storage" "sd_mod" ];
  # nct6687: the MSI board's sensor chip (fans/temps in `sensors`); out-of-tree driver
  boot.kernelModules = [ "kvm-intel" "nct6687" ];
  boot.extraModulePackages = [ config.boot.kernelPackages.nct6687d ];

  # WD SN770s drop off the bus when they enter deep power-saving states
  # ("nvme nvme0: controller is down; will reset: CSTS=0xffffffff").
  # Disable NVMe APST and PCIe ASPM so the drive never goes to sleep —
  # negligible power cost on a desktop. The same two params must be typed
  # at the installer's boot menu too (see README step 3).
  boot.kernelParams = [
    "nvme_core.default_ps_max_latency_us=0"
    "pcie_aspm=off"
  ];

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
