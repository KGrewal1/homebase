{ pkgs }:
{
  packages = with pkgs; [
    bat
    eza
    dust
    fd
    ripgrep
    htop
  ];
}
