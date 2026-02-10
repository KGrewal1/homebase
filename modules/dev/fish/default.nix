{ pkgs, ... }:
{
  packages = [ pkgs.fish ];
  configFiles."fish/config.fish".source = ./config.fish;
}
