# homebase

Personal dev environment -- nix modules + dotfiles + container images.

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

## What's included

| Category | Packages |
|---|---|
| Essentials | git, curl, vim, coreutils, bash, cacert |
| Shell | fish, starship, zellij |
| Modern coreutils | bat, eza, dust, fd, ripgrep, htop |
| Dev tools | just, tokei |
| Python | python 3.12, uv, ruff |
| Native libs | libstdc++, zlib, openssl, libffi, xz, bzip2, readline |
| CUDA (cuda image only) | cudatoolkit, cudnn, nccl |

Dotfiles for fish, starship, and zellij are baked into the container.

## Using modules in other projects

Each tool has its own module in `modules/`. Import them from a project's `devenv.yaml`:

```yaml
inputs:
  nixpkgs:
    url: github:NixOS/nixpkgs/nixpkgs-unstable
  homebase:
    url: github:youruser/homebase
    flake: false
allowUnfree: true  # needed if importing cuda.nix

imports:
  - homebase/modules/fish.nix
  - homebase/modules/starship.nix
  - homebase/modules/python.nix
  - homebase/modules/cuda.nix
  - homebase/modules/dotfiles.nix
```

Then in the project's `devenv.nix`, add only project-specific config:

```nix
{ pkgs, ... }:
{
  # project-specific packages go here
}
```

### Available modules

```
modules/
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

## Adding a new tool

1. Create `modules/toolname.nix`:
   ```nix
   { pkgs, ... }:
   {
     packages = [ pkgs.toolname ];
   }
   ```
2. Add the package to `basePackages` in `flake.nix` (for the container images)
3. Rebuild: `nix build .#docker`
