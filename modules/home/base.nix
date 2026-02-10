{ ... }:
{
  home.stateVersion = "24.11";

  xdg.configFile."fish/config.fish".source = ../../dotfiles/fish/config.fish;
  xdg.configFile."zellij/config.kdl".source = ../../dotfiles/zellij/config.kdl;
  xdg.configFile."starship.toml".source = ../../dotfiles/starship.toml;
}
