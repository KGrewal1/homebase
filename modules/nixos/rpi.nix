{ modulesPath, ... }:

{
  imports = [
    "${modulesPath}/installer/sd-card/sd-image-aarch64.nix"
  ];

  networking.hostName = "homebase-rpi";

  # Console auto-login for headless setup
  services.getty.autologinUser = "dev";

  # Wireless support
  networking.wireless.enable = true;
}
