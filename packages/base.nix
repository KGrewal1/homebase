{ pkgs }:
{
  packages = with pkgs; [
    coreutils
    bashInteractive
    cacert
    git
    curl
    vim
  ];

  env = {
    SSL_CERT_FILE = "${pkgs.cacert}/etc/ssl/certs/ca-bundle.crt";
  };
}
