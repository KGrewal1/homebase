{ pkgs, lib, base, pkgsUnfree }:
let
  inherit (pkgs.dockerTools) usrBinEnv binSh caCertificates;

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

  dockerEnvPaths = [ usrBinEnv binSh caCertificates userNss sudoSetup pkgs.sudo ];

  configFileLinks = lib.concatStringsSep "\n" (lib.mapAttrsToList (target: cfg: ''
    mkdir -p /home/dev/.config/${builtins.dirOf target}
    ln -s ${cfg.source} /home/dev/.config/${target}
  '') base.configFiles);

  homeDirSetup = ''
    mkdir -p /home/dev/.cache /home/dev/.local/share /home/dev/.local/state
    mkdir -p /tmp
    chmod 1777 /tmp
    ${configFileLinks}
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

  mkCudaImage = cudaPkgs:
    let
      cuda = import ../packages/cuda.nix { cudaPackages = cudaPkgs; inherit lib; };
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
in
{
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
  docker-cuda12 = mkCudaImage pkgsUnfree.cudaPackages_12;
  docker-cuda13 = mkCudaImage pkgsUnfree.cudaPackages_13;
  docker-cuda = mkCudaImage pkgsUnfree.cudaPackages;
}
