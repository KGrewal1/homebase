{ pkgs, lib, ... }:

let
  base = import ../../packages/base.nix { inherit pkgs; };
  python = import ../../packages/python.nix { inherit pkgs lib; };
in
{
  environment.systemPackages = base.packages ++ python.packages;
  environment.variables = base.env // python.env;

  # Fish as default shell
  programs.fish.enable = true;

  # SSH
  services.openssh = {
    enable = true;
    settings.PasswordAuthentication = false;
  };

  # Dev user
  users.users.dev = {
    isNormalUser = true;
    extraGroups = [ "wheel" "video" ];
    shell = pkgs.fish;
  };
  security.sudo.wheelNeedsPassword = false;

  # Nix settings
  nix.settings.experimental-features = [ "nix-command" "flakes" ];

  system.stateVersion = "24.11";

  # Home-manager for dotfiles and user packages
  home-manager = {
    useGlobalPkgs = true;
    useUserPackages = true;
    users.dev = { imports = [ ../home/base.nix ../home/python.nix ]; };
  };
}
