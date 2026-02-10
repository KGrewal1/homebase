{ modulesPath, ... }:

{
  imports = [
    "${modulesPath}/installer/cd-dvd/installation-cd-minimal.nix"
  ];

  # EFI + legacy BIOS boot
  isoImage.makeEfiBootable = true;
  isoImage.makeUsbBootable = true;

  networking.hostName = "homebase";

  # Allow unfree packages (for CUDA overlay)
  nixpkgs.config.allowUnfree = true;
}
