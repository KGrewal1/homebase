{ pkgs, lib }:

let
  python = import ./python.nix { inherit pkgs lib; };

  # Collect all tool packages from modules/dev/ (single source of truth)
  devModuleDir = ../modules/dev;
  devModuleFiles = builtins.filter
    (f: f != "dotfiles.nix" && f != "cuda.nix")
    (builtins.attrNames (builtins.readDir devModuleDir));
  devToolPackages = builtins.concatMap
    (f: (import (devModuleDir + "/${f}") { inherit pkgs lib; }).packages)
    devModuleFiles;

  # System essentials (no individual devenv modules for these)
  systemPackages = with pkgs; [
    uutils-coreutils-noprefix
    bashInteractive
    cacert
    gnutar
    gzip
    gnused
    gnugrep
    findutils
    less
    procps
    which
  ];
in
{
  packages = systemPackages ++ devToolPackages ++ python.packages;

  env = {
    SSL_CERT_FILE = "${pkgs.cacert}/etc/ssl/certs/ca-bundle.crt";
  } // python.env;
}
