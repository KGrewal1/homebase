{ pkgs, lib }:
let
  python = pkgs.python312;

  # Native libraries needed by pip-installed wheels (numpy, torch, etc.)
  nativeLibs = with pkgs; [
    stdenv.cc.cc.lib  # libstdc++ (numpy, torch, etc.)
    zlib              # libz (numpy, pillow)
    openssl           # libssl/libcrypto (requests, cryptography)
    libffi            # libffi (ctypes, cffi)
    xz                # liblzma (pandas)
    bzip2             # libbz2 (pandas)
    readline          # libreadline (interactive python)
  ];
in
{
  packages = [
    python
    pkgs.uv
    pkgs.ruff
  ] ++ nativeLibs;

  env = {
    UV_PYTHON_PREFERENCE = "system";
    UV_PYTHON = "${python}/bin/python3";
    LD_LIBRARY_PATH = lib.makeLibraryPath nativeLibs;
  };
}
