{ cudaPackages, lib }:
let
  cudaModuleDir = ../modules/cuda;
  cudaModuleFiles = builtins.attrNames (builtins.readDir cudaModuleDir);
  cudaLibs = builtins.concatMap
    (f: (import (cudaModuleDir + "/${f}") { inherit cudaPackages lib; }).packages)
    cudaModuleFiles;
in
{
  packages = cudaLibs;
  env = {
    CUDA_HOME = "${cudaPackages.cudatoolkit}";
    LD_LIBRARY_PATH = lib.makeLibraryPath cudaLibs;
  };
}
