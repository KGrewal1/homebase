{ pkgs, lib, ... }:

let p = import ../../packages/cuda.nix { cudaPackages = pkgs.cudaPackages; inherit lib; };
in
{
  packages = p.packages;
  env = p.env;
}
