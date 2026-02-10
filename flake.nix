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
        config = {
          allowUnfree = true;
          cudaSupport = true;
        };
      };

      lib = pkgs.lib;

      # Shared package sets
      base = import ./packages/base.nix { inherit pkgs; };
      shell = import ./packages/shell.nix { inherit pkgs; };
      coreutils = import ./packages/coreutils.nix { inherit pkgs; };
      dev = import ./packages/dev.nix { inherit pkgs; };
      python = import ./packages/python.nix { inherit pkgs lib; };

      allPackages =
        base.packages
        ++ shell.packages
        ++ coreutils.packages
        ++ dev.packages
        ++ python.packages;

      dotfiles = ./dotfiles;

      entrypoint = pkgs.writeShellScript "homebase-entry" ''
        export HOME=/tmp/homebase
        export XDG_CONFIG_HOME=$HOME/.config
        export XDG_CACHE_HOME=$HOME/.cache
        export XDG_DATA_HOME=$HOME/.local/share
        export XDG_STATE_HOME=$HOME/.local/state
        mkdir -p $XDG_CONFIG_HOME $XDG_CACHE_HOME $XDG_DATA_HOME $XDG_STATE_HOME
        cp -r ${dotfiles}/fish $XDG_CONFIG_HOME/fish
        cp -r ${dotfiles}/zellij $XDG_CONFIG_HOME/zellij
        cp ${dotfiles}/starship.toml $XDG_CONFIG_HOME/starship.toml
        chmod -R u+w $XDG_CONFIG_HOME
        cd $HOME
        exec fish "$@"
      '';

      baseEnv = [
        "UV_PYTHON_PREFERENCE=system"
        "UV_PYTHON=${python.env.UV_PYTHON}"
        "SSL_CERT_FILE=${base.env.SSL_CERT_FILE}"
        "LD_LIBRARY_PATH=${python.env.LD_LIBRARY_PATH}"
      ];

      # Helper: build a CUDA image given a cudaPackages set
      mkCudaImage = cudaPkgs:
        let
          cuda = import ./packages/cuda.nix { cudaPackages = cudaPkgs; inherit lib; };
        in
        pkgs.dockerTools.buildLayeredImage {
          name = "homebase-cuda";
          tag = cudaPkgs.cudatoolkit.version;
          contents = allPackages ++ cuda.packages;
          config = {
            Cmd = [ "${entrypoint}" ];
            Env = baseEnv ++ [
              "LD_LIBRARY_PATH=${python.env.LD_LIBRARY_PATH}:${cuda.env.LD_LIBRARY_PATH}"
              "CUDA_HOME=${cuda.env.CUDA_HOME}"
              "NVIDIA_VISIBLE_DEVICES=all"
              "NVIDIA_DRIVER_CAPABILITIES=compute,utility"
            ];
          };
        };

      mkNixosSystem = { system, modules }:
        nixpkgs.lib.nixosSystem {
          inherit system;
          specialArgs = { inherit inputs; };
          modules = [ home-manager.nixosModules.home-manager ] ++ modules;
        };

      inputs = { inherit nixpkgs home-manager; };
    in
    {
      packages.${system} = {
        # Base image: dev tools + python, no CUDA
        docker = pkgs.dockerTools.buildLayeredImage {
          name = "homebase";
          tag = "latest";
          contents = allPackages;
          config = {
            Cmd = [ "${entrypoint}" ];
            Env = baseEnv;
          };
        };

        # CUDA 12 (latest 12.x in nixpkgs)
        docker-cuda12 = mkCudaImage pkgsUnfree.cudaPackages_12;

        # CUDA 13 (latest 13.x in nixpkgs)
        docker-cuda13 = mkCudaImage pkgsUnfree.cudaPackages_13;

        # Default CUDA (whatever nixpkgs considers current)
        docker-cuda = mkCudaImage pkgsUnfree.cudaPackages;
      };

      nixosConfigurations = {
        # x86_64 dev machine (no CUDA)
        dev = mkNixosSystem {
          system = "x86_64-linux";
          modules = [ ./modules/nixos/base.nix ./modules/nixos/desktop.nix ];
        };

        # x86_64 CUDA dev machine
        dev-cuda = mkNixosSystem {
          system = "x86_64-linux";
          modules = [ ./modules/nixos/base.nix ./modules/nixos/desktop.nix ./modules/nixos/cuda.nix ];
        };

        # Raspberry Pi
        rpi = mkNixosSystem {
          system = "aarch64-linux";
          modules = [ ./modules/nixos/base.nix ./modules/nixos/rpi.nix ];
        };
      };
    };
}
