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

      # All packages: system essentials + tools (from modules/dev/) + python
      base = import ./packages/base.nix { inherit pkgs lib; };

      dotfiles = ./dotfiles;

      # Docker environment helpers
      inherit (pkgs.dockerTools) usrBinEnv binSh caCertificates;

      # fakeNss extended with a dev user (uid 1000) and wheel group
      userNss = pkgs.runCommand "user-nss" {} ''
        mkdir -p $out/etc
        cat > $out/etc/passwd <<'EOF'
root:x:0:0:root:/root:/bin/sh
nobody:x:65534:65534:nobody:/nonexistent:/bin/sh
dev:x:1000:1000:dev:/home/dev:${pkgs.fish}/bin/fish
EOF
        cat > $out/etc/group <<'EOF'
root:x:0:
wheel:x:1:dev
nobody:x:65534:
dev:x:1000:
EOF
        cat > $out/etc/nsswitch.conf <<'EOF'
hosts: files dns
EOF
      '';

      # Passwordless sudo for wheel group
      sudoSetup = pkgs.runCommand "sudo-setup" {} ''
        mkdir -p $out/etc/sudoers.d $out/etc/pam.d
        echo "%wheel ALL=(ALL) NOPASSWD: ALL" > $out/etc/sudoers.d/wheel
        chmod 440 $out/etc/sudoers.d/wheel
        cat > $out/etc/sudoers <<'EOF'
root ALL=(ALL) ALL
@includedir /etc/sudoers.d
EOF
        chmod 440 $out/etc/sudoers
        cat > $out/etc/pam.d/sudo <<'EOF'
auth       sufficient pam_permit.so
account    sufficient pam_permit.so
session    sufficient pam_permit.so
EOF
      '';

      # Shared docker contents: env helpers + user setup
      dockerEnvPaths = [
        usrBinEnv
        binSh
        caCertificates
        userNss
        sudoSetup
        pkgs.sudo
      ];

      # Create writable /home/dev with dotfiles symlinked into the store
      homeDirSetup = ''
        mkdir -p /home/dev/.config/fish /home/dev/.config/zellij
        mkdir -p /home/dev/.cache /home/dev/.local/share /home/dev/.local/state
        mkdir -p /tmp
        chmod 1777 /tmp
        ln -s ${dotfiles}/fish/config.fish /home/dev/.config/fish/config.fish
        ln -s ${dotfiles}/zellij/config.kdl /home/dev/.config/zellij/config.kdl
        ln -s ${dotfiles}/starship.toml /home/dev/.config/starship.toml
        chown -R 1000:1000 /home/dev
      '';

      entrypoint = pkgs.writeShellScript "homebase-entry" ''
        cd /home/dev
        exec fish "$@"
      '';

      baseEnv = [
        "HOME=/home/dev"
        "USER=dev"
        "UV_PYTHON_PREFERENCE=system"
        "UV_PYTHON=${base.env.UV_PYTHON}"
        "LD_LIBRARY_PATH=${base.env.LD_LIBRARY_PATH}"
      ];

      # Helper: build a CUDA image given a cudaPackages set
      mkCudaImage = cudaPkgs:
        let
          cuda = import ./packages/cuda.nix { cudaPackages = cudaPkgs; inherit lib; };
        in
        pkgs.dockerTools.buildLayeredImage {
          name = "homebase-cuda";
          tag = cudaPkgs.cudatoolkit.version;
          contents = base.packages ++ cuda.packages ++ dockerEnvPaths;
          enableFakechroot = true;
          fakeRootCommands = homeDirSetup;
          config = {
            Cmd = [ "${entrypoint}" ];
            User = "dev";
            Env = baseEnv ++ [
              "LD_LIBRARY_PATH=${base.env.LD_LIBRARY_PATH}:${cuda.env.LD_LIBRARY_PATH}"
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
          contents = base.packages ++ dockerEnvPaths;
          enableFakechroot = true;
          fakeRootCommands = homeDirSetup;
          config = {
            Cmd = [ "${entrypoint}" ];
            User = "dev";
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
