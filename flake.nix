{
  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixpkgs-unstable";
    home-manager = {
      url = "github:nix-community/home-manager";
      inputs.nixpkgs.follows = "nixpkgs";
    };
  };

  outputs = { self, nixpkgs, home-manager }:
    let
      system = "x86_64-linux";
      pkgs = import nixpkgs { inherit system; };
      pkgsUnfree = import nixpkgs {
        inherit system;
        config = { allowUnfree = true; cudaSupport = true; };
      };
      lib = pkgs.lib;

      base = import ./packages/packages.nix { inherit pkgs lib; };

      mkNixosSystem = { system, modules }:
        nixpkgs.lib.nixosSystem {
          inherit system;
          specialArgs = { inherit inputs; };
          modules = [ home-manager.nixosModules.home-manager ] ++ modules;
        };

      inputs = { inherit nixpkgs home-manager; };
    in
    {
      packages.${system} = import ./docker { inherit pkgs lib base pkgsUnfree; };

      nixosConfigurations = {
        dev = mkNixosSystem {
          system = "x86_64-linux";
          modules = [ ./modules/nixos/base.nix ./modules/nixos/desktop.nix ];
        };
        dev-cuda = mkNixosSystem {
          system = "x86_64-linux";
          modules = [ ./modules/nixos/base.nix ./modules/nixos/desktop.nix ./modules/nixos/cuda.nix ];
        };
        rpi = mkNixosSystem {
          system = "aarch64-linux";
          modules = [ ./modules/nixos/base.nix ./modules/nixos/rpi.nix ];
        };
      };
    };
}
