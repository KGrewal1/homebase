{ pkgs, lib, ... }:

let
  cudaLibs = with pkgs; [
    cudaPackages.cudatoolkit
    cudaPackages.cudnn
    cudaPackages.nccl
  ];
in
{
  packages = cudaLibs;

  env = {
    CUDA_HOME = "${pkgs.cudaPackages.cudatoolkit}";
    LD_LIBRARY_PATH = lib.makeLibraryPath cudaLibs;
  };
}
