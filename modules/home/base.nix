{ pkgs, ... }:

let
  base = import ../../packages/base.nix { inherit pkgs; };
  shell = import ../../packages/shell.nix { inherit pkgs; };
  coreutils = import ../../packages/coreutils.nix { inherit pkgs; };
  dev = import ../../packages/dev.nix { inherit pkgs; };
in
{
  home.stateVersion = "24.11";

  home.packages =
    base.packages
    ++ shell.packages
    ++ coreutils.packages
    ++ dev.packages;

  xdg.configFile."fish/config.fish".source = ../../dotfiles/fish/config.fish;
  xdg.configFile."zellij/config.kdl".source = ../../dotfiles/zellij/config.kdl;
  xdg.configFile."starship.toml".source = ../../dotfiles/starship.toml;
}
