{ pkgs, lib }:
let
  devModuleDir = ../modules/dev;
  devModuleFiles = builtins.attrNames (builtins.readDir devModuleDir);
  devModules = map
    (f: import (devModuleDir + "/${f}") { inherit pkgs lib; })
    devModuleFiles;

  devToolPackages = builtins.concatMap (m: m.packages) devModules;
  devConfigFiles = lib.foldl' (acc: m: acc // (m.configFiles or {})) {} devModules;
  devEnv = lib.foldl' (acc: m: acc // (m.env or {})) {} devModules;
in
{
  packages = with pkgs; [
    bashInteractive
    cacert
    curl
    findutils
    gnused
    gnutar
    gzip
    ncurses
    procps
    uutils-coreutils-noprefix
    which
  ] ++ devToolPackages;

  env = {
    SSL_CERT_FILE = "${pkgs.cacert}/etc/ssl/certs/ca-bundle.crt";
  } // devEnv;

  configFiles = devConfigFiles;
}
