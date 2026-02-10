{ pkgs, lib, ... }:

let p = import ../../packages/python.nix { inherit pkgs lib; };
in
{
  home.packages = p.packages;
  home.sessionVariables = p.env;
}
