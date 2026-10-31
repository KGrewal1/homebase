# NVIDIA desktop driver + CUDA for an Ampere card (RTX 3070 Ti).
#
# Unlike cuda.nix (used for images), this does NOT set cudaSupport globally:
# that flag makes nixpkgs rebuild torch/opencv/etc. from source, which is
# hours of compiling and a lot of SSD writes.
{ config, pkgs, ... }:
{
  hardware.graphics = {
    enable = true;
    enable32Bit = true;
  };

  services.xserver.videoDrivers = [ "nvidia" ];

  hardware.nvidia = {
    open = true; # open kernel module, recommended for Turing and newer
    modesetting.enable = true; # required for Wayland/COSMIC
    powerManagement.enable = true; # save VRAM across suspend; else black/garbled screen on resume
    nvidiaSettings = true;
    package = config.boot.kernelPackages.nvidiaPackages.stable;
  };

  # GPUs in Docker: `docker run --device nvidia.com/gpu=all ...`
  hardware.nvidia-container-toolkit.enable = true;

  environment.systemPackages = with pkgs; [
    nvtopPackages.nvidia
  ];
}
