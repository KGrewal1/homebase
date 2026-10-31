{
  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixpkgs-unstable";
    home-manager = {
      url = "github:nix-community/home-manager";
      inputs.nixpkgs.follows = "nixpkgs";
    };
    # Declarative disk partitioning (used to install neptune)
    disko = {
      url = "github:nix-community/disko";
      inputs.nixpkgs.follows = "nixpkgs";
    };
    # Encrypted secrets in the repo (Sirius creds etc.)
    sops-nix = {
      url = "github:Mic92/sops-nix";
      inputs.nixpkgs.follows = "nixpkgs";
    };
    # Hardware presets (Intel CPU, SSD)
    nixos-hardware.url = "github:NixOS/nixos-hardware";
    # Declarative COSMIC settings (shortcuts, panel, theme) via home-manager
    cosmic-manager = {
      url = "github:HeitorAugustoLN/cosmic-manager";
      inputs.nixpkgs.follows = "nixpkgs";
      inputs.home-manager.follows = "home-manager";
    };
    # Prebuilt nix-index database: `, cowsay` runs anything without installing
    nix-index-database = {
      url = "github:nix-community/nix-index-database";
      inputs.nixpkgs.follows = "nixpkgs";
    };
  };

  outputs = { self, nixpkgs, home-manager, ... }@inputs:
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
    in
    {
      packages.${system} = import ./docker { inherit pkgs lib base pkgsUnfree; };

      nixosConfigurations = {
        # Main desktop (MSI MS-7D25, i7-12700K, RTX 3070 Ti)
        neptune = mkNixosSystem {
          system = "x86_64-linux";
          modules = [ ./hosts/neptune ];
        };

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
