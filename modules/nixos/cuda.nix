{ pkgs, lib, ... }:

let
  cuda = import ../../packages/cuda.nix { cudaPackages = pkgs.cudaPackages; inherit lib; };
in
{
  environment.systemPackages = cuda.packages;

  environment.variables = cuda.env // {
    NVIDIA_VISIBLE_DEVICES = "all";
    NVIDIA_DRIVER_CAPABILITIES = "compute,utility";
  };

  # Enable NVIDIA drivers
  hardware.nvidia = {
    open = true;
    package = pkgs.linuxPackages.nvidiaPackages.stable;
  };
  services.xserver.videoDrivers = [ "nvidia" ];

  nixpkgs.config.allowUnfree = true;
  nixpkgs.config.cudaSupport = true;
}
