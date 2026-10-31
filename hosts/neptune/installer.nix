# Offline installer USB for neptune.
#
#   nix build .#neptune-installer
#   sudo dd if=$(echo result/iso/*.iso) of=/dev/sdX bs=4M status=progress oflag=sync
#
# The ISO carries neptune's fully built system, so installing needs no
# network, no git clone and no compiling. Boot it, run `install-neptune`.
{ inputs, lib, pkgs, modulesPath, ... }:

let
  neptune = inputs.self.nixosConfigurations.neptune.config;
  toplevel = neptune.system.build.toplevel;
  disko = neptune.system.build.diskoScript; # destroy + format + mount, per disko.nix
  src = inputs.self.outPath; # this repo, as a fallback copy when offline
  target = neptune.disko.devices.disk.main.device;

  install-neptune = pkgs.writeShellApplication {
    name = "install-neptune";
    runtimeInputs = with pkgs; [ git cifs-utils util-linux coreutils gnugrep ];
    text = ''
      if [ "$(id -u)" -ne 0 ]; then exec sudo "$0" "$@"; fi

      DISK=${target}
      REPO=https://github.com/KGrewal1/homebase
      step() { printf '\n\033[1;34m==> %s\033[0m\n' "$*"; }

      if [ "$(cat /sys/module/nvme_core/parameters/default_ps_max_latency_us)" != 0 ]; then
        echo "WARNING: NVMe power saving is on; the SN770 may drop out mid-install."
      fi

      if [ ! -e "$DISK" ]; then
        echo "Target drive $DISK not found. NVMe drives present:"
        for d in /dev/disk/by-id/nvme-*; do echo "  $d"; done
        exit 1
      fi

      step "This will ERASE $DISK"
      lsblk -o NAME,MODEL,SERIAL,SIZE,MOUNTPOINTS "$(readlink -f "$DISK")"
      read -rp "Type 'wipe' to continue: " answer
      [ "$answer" = wipe ] || { echo "Aborted, nothing touched."; exit 1; }

      step "Partitioning, formatting, mounting at /mnt"
      ${disko} --yes-wipe-all-disks

      step "Installing neptune (offline, straight from the USB)"
      nixos-install --system ${toplevel} --no-root-passwd --no-channel-copy

      step "Set the password for kirpal"
      until nixos-enter --root /mnt -c 'passwd kirpal'; do echo "Try again."; done

      step "Putting homebase in ~/Documents/homebase"
      dest=/mnt/home/kirpal/Documents/homebase
      mkdir -p "$(dirname "$dest")"
      rm -rf "$dest"
      if git clone -q "$REPO" "$dest"; then
        echo "Cloned from GitHub."
      else
        cp -r --no-preserve=mode ${src} "$dest"
        echo "No network: copied the USB's snapshot (not a git checkout)."
        echo "Re-clone after boot: git clone $REPO ~/Documents/homebase"
      fi
      chown -R 1000:100 /mnt/home/kirpal

      read -rp "Restore Tailscale identity from Sirius? [y/N] " ts
      if [[ "$ts" == [yY]* ]]; then
        mkdir -p /tmp/sirius /mnt/var/lib/tailscale
        if mount.cifs //192.168.1.134/Kirpal_Share /tmp/sirius -o username=kirpal,vers=3.0; then
          if install -m 600 /tmp/sirius/tailscaled.state /mnt/var/lib/tailscale/tailscaled.state; then
            echo "Restored. Delete tailscaled.state from Sirius after first boot."
          fi
          umount /tmp/sirius
        else
          echo "Couldn't mount Sirius; skipping. Run 'sudo tailscale up' after boot instead."
        fi
      fi

      step "Done. Remove the USB and reboot."
    '';
  };
in
{
  imports = [ "${modulesPath}/installer/cd-dvd/installation-cd-minimal.nix" ];

  # SN770 drops off the bus in deep power states (same as hardware.nix).
  boot.kernelParams = [ "nvme_core.default_ps_max_latency_us=0" "pcie_aspm=off" ];

  # Ship neptune's whole system + disk script inside the ISO's store.
  isoImage.storeContents = [ toplevel disko ];
  isoImage.squashfsCompression = "zstd -Xcompression-level 6"; # xz is very slow on ~10 GB

  console.keyMap = "uk";
  environment.systemPackages = [ install-neptune pkgs.git ];
  services.getty.helpLine = lib.mkAfter ''

    To install neptune (wipes the SN770 220734800566), run:  install-neptune
  '';

  nix.settings.experimental-features = [ "nix-command" "flakes" ];
  nixpkgs.hostPlatform = "x86_64-linux";
}
