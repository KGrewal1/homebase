{ pkgs, lib }:

let
  python = import ./python.nix { inherit pkgs lib; };

  # Collect all tool packages from modules/dev/ (single source of truth)
  devModuleDir = ../modules/dev;
  devModuleFiles =
    (builtins.attrNames (builtins.readDir devModuleDir));
  devToolPackages = builtins.concatMap
    (f: (import (devModuleDir + "/${f}") { inherit pkgs lib; }).packages)
    devModuleFiles;


  baseModuleDir = ../modules/base;
  baseModuleFiles =
    (builtins.attrNames (builtins.readDir baseModuleDir));
  baseToolPackages = builtins.concatMap
    (f: (import (baseModuleDir + "/${f}") { inherit pkgs lib; }).packages)
    baseModuleFiles;

in
{
  packages = baseToolPackages ++ devToolPackages ++ python.packages;

  env = {
    SSL_CERT_FILE = "${pkgs.cacert}/etc/ssl/certs/ca-bundle.crt";
  } // python.env;
}
