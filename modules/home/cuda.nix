{ pkgs, lib, ... }:

let p = import ../../packages/cuda.nix { cudaPackages = pkgs.cudaPackages; inherit lib; };
in
{
  home.packages = p.packages;
  home.sessionVariables = p.env;
}
