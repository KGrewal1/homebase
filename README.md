# homebase

Personal dev environment -- nix modules + dotfiles + container images + bootable system images.

## Container images

Two variants:

```bash
# Base image: dev tools + python (~1.2GB)
nix build .#docker
docker load -i result
docker run -it homebase

# CUDA image: base + CUDA toolkit/cuDNN/NCCL (~5GB)
nix build .#docker-cuda
docker load -i result
docker run --gpus all -it homebase-cuda
```

Rebuild after changes:

```bash
nix build .#docker       # or .#docker-cuda
docker load -i result
```

Push to a registry:

```bash
docker tag homebase:latest youruser/homebase:latest
docker push youruser/homebase:latest

docker tag homebase-cuda:latest youruser/homebase-cuda:latest
docker push youruser/homebase-cuda:latest
```

### CUDA compatibility

The CUDA image can be **built** on any machine (no GPU needed). To **run** it, the host NVIDIA driver must support the CUDA toolkit version in the image. Vast.ai instances have recent drivers so this is not an issue there.

## System images (ISOs / SD cards)

Build bootable images for setting up dev machines:

```bash
# x86_64 dev ISO (no CUDA)
nix build .#nixosConfigurations.dev.config.system.build.isoImage

# x86_64 CUDA dev ISO
nix build .#nixosConfigurations.dev-cuda.config.system.build.isoImage

# Raspberry Pi SD card image (aarch64)
nix build .#nixosConfigurations.rpi.config.system.build.sdImage
```

### Flashing

```bash
# ISO to USB drive
sudo dd if=result/iso/*.iso of=/dev/sdX bs=4M status=progress oflag=sync

# SD card image for RPi
zstd -d result/sd-image/*.img.zst -o rpi.img
sudo dd if=rpi.img of=/dev/sdX bs=4M status=progress oflag=sync
```

### Cross-building ARM

The RPi image targets aarch64. To build from an x86_64 host, either:

- Enable binfmt emulation: add `boot.binfmt.emulatedSystems = ["aarch64-linux"];` to your NixOS config
- Use a remote aarch64 builder via `nix.buildMachines`

## What's included

| Category | Packages |
|---|---|
| Essentials | git, curl, vim, coreutils, bash, cacert |
| Shell | fish, starship, zellij |
| Modern coreutils | bat, eza, dust, fd, ripgrep, htop |
| Dev tools | just, tokei, gh |
| Python | python 3.12, uv, ruff |
| Native libs | libstdc++, zlib, openssl, libffi, xz, bzip2, readline |
| CUDA (cuda variants only) | cudatoolkit, cudnn, nccl |

Dotfiles for fish, starship, and zellij are managed by home-manager on NixOS and baked into container entrypoints.

## Using modules in other projects

Each tool has its own devenv module in `modules/dev/`. Import them from a project's `devenv.yaml`:

```yaml
inputs:
  nixpkgs:
    url: github:NixOS/nixpkgs/nixpkgs-unstable
  homebase:
    url: github:youruser/homebase
    flake: false
allowUnfree: true  # needed if importing cuda.nix

imports:
  - homebase/modules/dev/fish.nix
  - homebase/modules/dev/starship.nix
  - homebase/modules/dev/python.nix
  - homebase/modules/dev/cuda.nix
  - homebase/modules/dev/dotfiles.nix
```

Then in the project's `devenv.nix`, add only project-specific config:

```nix
{ pkgs, ... }:
{
  # project-specific packages go here
}
```

### Available devenv modules

```
modules/dev/
├── bat.nix
├── cuda.nix        # CUDA toolkit + cuDNN + NCCL, sets CUDA_HOME
├── curl.nix
├── dotfiles.nix    # copies fish/starship/zellij configs into $HOME
├── dust.nix
├── eza.nix
├── fd.nix
├── fish.nix
├── git.nix
├── htop.nix
├── just.nix
├── python.nix      # python 3.12 + uv + ruff + native libs, sets UV_PYTHON/LD_LIBRARY_PATH
├── ripgrep.nix
├── starship.nix
├── tokei.nix
├── vim.nix
└── zellij.nix
```

## Architecture

```
packages/        # shared package definitions (single source of truth)
modules/
  dev/           # devenv modules for per-project use
  home/          # home-manager modules (dotfiles + user packages)
  nixos/         # NixOS system modules (compose with home-manager)
```

Package lists are defined once in `packages/` and consumed by Docker images (`flake.nix`), NixOS system configs (`modules/nixos/`), and home-manager (`modules/home/`). NixOS configs use home-manager to manage dotfiles and user-level packages for the `dev` user.

## Adding a new tool

1. Create `modules/dev/toolname.nix`:
   ```nix
   { pkgs, ... }:
   {
     packages = [ pkgs.toolname ];
   }
   ```
2. Add the package to the appropriate file in `packages/` (for container and system images)
3. Rebuild: `nix build .#docker`
