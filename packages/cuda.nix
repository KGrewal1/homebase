{ cudaPackages, lib }:
let
  cudaLibs = [
    cudaPackages.cudatoolkit
    cudaPackages.cudnn
    cudaPackages.nccl
  ];
in
{
  packages = cudaLibs;

  env = {
    CUDA_HOME = "${cudaPackages.cudatoolkit}";
    LD_LIBRARY_PATH = lib.makeLibraryPath cudaLibs;
  };
}
