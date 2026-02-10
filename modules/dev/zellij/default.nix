{ pkgs, ... }:
{
  packages = [ pkgs.zellij ];
  configFiles."zellij/config.kdl".source = ./config.kdl;
}
