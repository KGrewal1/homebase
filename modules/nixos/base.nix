{ pkgs, lib, ... }:

let
  base = import ../../packages/base.nix { inherit pkgs lib; };
in
{
  environment.systemPackages = base.packages;
  environment.variables = base.env;

  programs.fish.enable = true;

  services.openssh = {
    enable = true;
    settings.PasswordAuthentication = false;
  };

  users.users.dev = {
    isNormalUser = true;
    extraGroups = [ "wheel" "video" ];
    shell = pkgs.fish;
  };
  security.sudo.wheelNeedsPassword = false;

  nix.settings.experimental-features = [ "nix-command" "flakes" ];

  system.stateVersion = "24.11";

  # Home-manager for dotfiles only — packages come from system level
  home-manager = {
    useGlobalPkgs = true;
    useUserPackages = true;
    users.dev = { imports = [ ../home/base.nix ]; };
  };
}
