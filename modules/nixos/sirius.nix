# Sirius NAS share, mounted on first access.
# The password lives encrypted in hosts/neptune/secrets.yaml (key: sirius/password);
# sops-nix decrypts it at boot into a root-only credentials file.
{ config, ... }:
{
  sops.secrets."sirius/password" = { };

  sops.templates."sirius-creds" = {
    owner = "root";
    mode = "0400";
    content = ''
      username=kirpal
      password=${config.sops.placeholder."sirius/password"}
    '';
  };

  fileSystems."/mnt/sirius/Kirpal_Share" = {
    device = "//sirius.local/Kirpal_Share";
    fsType = "cifs";
    options = [
      "credentials=${config.sops.templates."sirius-creds".path}"
      "uid=1000"
      "gid=100"
      "vers=3.0"
      "mfsymlinks" # keep symlinks on SMB
      "_netdev"
      "nofail"
      "noauto"
      "x-systemd.automount"
      "x-systemd.idle-timeout=600"
      "x-systemd.mount-timeout=15s"
    ];
  };
}
