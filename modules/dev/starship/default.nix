{ pkgs, ... }:
{
  packages = [ pkgs.starship ];
  configFiles."starship.toml".source = ./starship.toml;
}
