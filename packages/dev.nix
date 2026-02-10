{ pkgs }:
{
  packages = with pkgs; [
    just
    tokei
    gh
  ];
}
