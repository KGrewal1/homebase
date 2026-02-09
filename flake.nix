{
  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixpkgs-unstable";
  };

  outputs = { self, nixpkgs }:
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

      python = pkgs.python312;
      dotfiles = ./dotfiles;

      # Native libraries needed by pip-installed wheels (numpy, torch, etc.)
      nativeLibs = with pkgs; [
        stdenv.cc.cc.lib  # libstdc++
        zlib              # libz (numpy, pillow)
        openssl           # libssl/libcrypto (requests, cryptography)
        libffi            # libffi (ctypes, cffi)
        xz                # liblzma (pandas)
        bzip2             # libbz2 (pandas)
        readline          # libreadline (interactive python)
      ];

      libPath = pkgs.lib.makeLibraryPath nativeLibs;

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

      basePackages = with pkgs; [
        # Essentials
        coreutils
        bashInteractive
        cacert
        git
        curl
        vim

        # Shell
        fish
        starship
        zellij

        # Modern coreutils
        bat
        eza
        dust
        fd
        ripgrep
        htop

        # Dev tools
        just
        tokei
        gh

        # Python
        python
        uv
        ruff
      ] ++ nativeLibs;

      baseEnv = [
        "UV_PYTHON_PREFERENCE=system"
        "UV_PYTHON=${python}/bin/python3"
        "SSL_CERT_FILE=${pkgs.cacert}/etc/ssl/certs/ca-bundle.crt"
      ];

      # Helper: build a CUDA image given a cudaPackages set
      mkCudaImage = cudaPkgs:
        let
          cudaLibs = [
            cudaPkgs.cudatoolkit
            cudaPkgs.cudnn
            cudaPkgs.nccl
          ];
          cudaLibPath = pkgs.lib.makeLibraryPath cudaLibs;
        in
        pkgs.dockerTools.buildLayeredImage {
          name = "homebase-cuda";
          tag = cudaPkgs.cudatoolkit.version;
          contents = basePackages ++ cudaLibs;
          config = {
            Cmd = [ "${entrypoint}" ];
            Env = baseEnv ++ [
              "LD_LIBRARY_PATH=${libPath}:${cudaLibPath}"
              "CUDA_HOME=${cudaPkgs.cudatoolkit}"
              "NVIDIA_VISIBLE_DEVICES=all"
              "NVIDIA_DRIVER_CAPABILITIES=compute,utility"
            ];
          };
        };
    in
    {
      packages.${system} = {
        # Base image: dev tools + python, no CUDA
        docker = pkgs.dockerTools.buildLayeredImage {
          name = "homebase";
          tag = "latest";
          contents = basePackages;
          config = {
            Cmd = [ "${entrypoint}" ];
            Env = baseEnv ++ [
              "LD_LIBRARY_PATH=${libPath}"
            ];
          };
        };

        # CUDA 12 (latest 12.x in nixpkgs)
        docker-cuda12 = mkCudaImage pkgsUnfree.cudaPackages_12;

        # CUDA 13 (latest 13.x in nixpkgs, if available)
        docker-cuda13 = mkCudaImage pkgsUnfree.cudaPackages_13;

        # Default CUDA (whatever nixpkgs considers current)
        docker-cuda = mkCudaImage pkgsUnfree.cudaPackages;
      };
    };
}
