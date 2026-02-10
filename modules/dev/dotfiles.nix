{ pkgs, ... }:

let
  dotfiles = ../../dotfiles;
in
{
  enterShell = ''
    for dir in fish zellij; do
      if [ ! -e "$HOME/.config/$dir" ]; then
        mkdir -p "$HOME/.config"
        cp -r ${dotfiles}/$dir "$HOME/.config/$dir"
      fi
    done
    if [ ! -e "$HOME/.config/starship.toml" ]; then
      mkdir -p "$HOME/.config"
      cp ${dotfiles}/starship.toml "$HOME/.config/starship.toml"
    fi
  '';
}
