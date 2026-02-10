{ pkgs, lib, ... }:

let p = import ../../packages/python.nix { inherit pkgs lib; };
in
{
  packages = p.packages;
  env = p.env;
}
