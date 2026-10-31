# neptune

Main desktop: MSI MS-7D25, i7-12700K, RTX 3070 Ti, COSMIC desktop.

| Drive | Serial | Role |
|---|---|---|
| WD_BLACK SN770 2 TB | `220734800566` | **system drive** (targeted by `disko.nix`) |
| WD_BLACK SN770 2 TB | `2152BC451902` | worn out (SMART failed) — remove or leave unused |
| Toshiba HDWE150 5 TB | — | NTFS data, mounted at `/mnt/toshiba` |

## 0. Before wiping anything (on the old Ubuntu install)

Sirius share is mounted at `~/Documents/sirius/Kirpal_Share` on the old system.
Download and write to it rather than the dying SSD.

1. **Let the backups finish** (`~/rsync-part3.log`, `~/rsync-windows.log`), then
   verify them — no output means everything matches:

   ```bash
   S=~/Documents/sirius/Kirpal_Share
   rsync -rlc --dry-run --itemize-changes ~/Documents/Part_III $S/
   rsync -rlc --dry-run --itemize-changes /media/kirpal/windowsDrive/Users/ $S/Windows_backup/Users/
   ```

2. **Back up the rest of home** (dotfiles, keys, projects). Re-downloadable
   caches and build output are skipped:

   ```bash
   rsync -rlt --partial --info=progress2 --log-file=$S/rsync-home.log \
     --exclude='/Documents/Part_III' --exclude='/Documents/sirius' \
     --exclude='/.cache' --exclude='/.rustup/toolchains' \
     --exclude='/.cargo/registry' --exclude='/.cargo/git' \
     --exclude='target/' --exclude='node_modules/' --exclude='/snap' \
     --exclude='/.local/share/Trash' --exclude='/.local/share/uv/python' \
     ~/ $S/neptune_home/
   ```

   Make sure `~/.ssh` and `~/.gnupg` made it (needed for signed commits):

   ```bash
   ls $S/neptune_home/.ssh $S/neptune_home/.gnupg
   ```

3. **Make sure homebase is pushed to `master`** — the installer clones it from GitHub.

4. **Save Tailscale's identity** so the new install comes back as the same
   machine (`neptune`, `100.113.28.32`, same ACLs) without logging in again.
   This file is a credential: it's deleted from Sirius again after first boot.

   ```bash
   sudo cp /var/lib/tailscale/tailscaled.state ~/Documents/sirius/Kirpal_Share/tailscaled.state
   ```

   Do this last, right before shutting down for the install, and don't boot the
   old Ubuntu drive again afterwards — two machines with one identity fight.

## 1. Make the install USB

No custom ISO is needed — the official one installs this flake directly.

```bash
cd ~/Documents/sirius/Kirpal_Share
ISO=latest-nixos-minimal-x86_64-linux.iso
curl -LO https://channels.nixos.org/nixos-unstable/$ISO
# the .sha256 names the versioned file, so compare hashes directly
[ "$(curl -sL https://channels.nixos.org/nixos-unstable/$ISO.sha256 | cut -d' ' -f1)" = \
  "$(sha256sum $ISO | cut -d' ' -f1)" ] && echo OK || echo MISMATCH
```

(Prefer a desktop installer? Grab the unstable *graphical* ISO from
<https://nixos.org/download> instead — same steps after it boots.)

Plug in a USB stick (≥ 4 GB, **it will be wiped**) and find it:

```bash
lsblk -d -o NAME,MODEL,SIZE,TRAN     # the one with TRAN=usb, e.g. sdb
```

Write it — double-check `sdX`; never `nvme*` or `sda` (the Toshiba):

```bash
sudo dd if=$ISO of=/dev/sdX bs=4M status=progress oflag=sync
```

## 2. BIOS (MSI: press Del at boot)

- **Secure Boot: Disabled** — systemd-boot isn't signed.
- Boot the USB via the one-time boot menu (**F11**).
- After installing, set the SN770 `220734800566` as first boot device.
  Once happy, physically remove the worn SN770 (`2152BC451902`).

## 3. Install

1. Boot the USB. If the screen is blank, pick the `nomodeset` boot entry.
   Connect to the network (ethernet just works; wifi on minimal: `sudo systemctl start wpa_supplicant`
   then `wpa_cli`, or use `nmtui` on the graphical ISO).

2. Get the config. The ISO has no git, so borrow it from nixpkgs for this
   shell (it lives in RAM; nothing touches the disks):

   ```bash
   nix-shell -p git cifs-utils   # a shell with git + SMB mounting; stay in it
   cd ~                          # /home/nixos on the live USB
   git clone https://github.com/KGrewal1/homebase
   cd homebase
   ```

   The repo is public, so no GitHub login is needed to clone.

3. Check the target drive is the healthy one:

   ```bash
   ls -l /dev/disk/by-id/ | grep 220734800566
   ```

4. Partition + format + mount (**wipes that drive**):

   ```bash
   sudo nix --experimental-features "nix-command flakes" \
     run github:nix-community/disko/latest -- \
     --mode destroy,format,mount --flake .#neptune
   ```

5. Install, then set your password:

   ```bash
   sudo nixos-install --flake .#neptune --no-root-passwd
   sudo nixos-enter --root /mnt -c 'passwd kirpal'
   ```

6. Copy the repo onto the new system so it's there after reboot.
   The live USB's files vanish on reboot; `/mnt` is the new drive. This is a
   plain copy (no git needed) and keeps the `.git` folder, so it's still a
   normal checkout on the new system:

   ```bash
   sudo mkdir -p /mnt/home/kirpal/Documents
   sudo cp -a /home/nixos/homebase /mnt/home/kirpal/Documents/
   sudo nixos-enter --root /mnt -c 'chown -R kirpal:users /home/kirpal'
   ```

7. Restore Tailscale's identity (saved in step 0.4), then reboot:

   ```bash
   sudo mkdir -p /tmp/sirius /mnt/var/lib/tailscale
   sudo $(which mount.cifs) //192.168.1.134/Kirpal_Share /tmp/sirius -o username=kirpal,vers=3.0
   sudo install -m 600 /tmp/sirius/tailscaled.state /mnt/var/lib/tailscale/tailscaled.state
   sudo umount /tmp/sirius
   reboot
   ```

   (Skipped this? No problem: the new system has git installed, so after
   first boot just run
   `git clone https://github.com/KGrewal1/homebase ~/Documents/homebase`.)

## 4. First boot

Tailscale should already be connected as `neptune` (Tailscale SSH is set in the
config). Check, then delete the saved credential from Sirius:

```bash
tailscale status --self        # expect: 100.113.28.32  neptune
rm /mnt/sirius/Kirpal_Share/tailscaled.state   # after mounting Sirius below
```

Didn't restore it? Remove the old `neptune` in the Tailscale admin console
(so the name is free), then run `sudo tailscale up` and open the login link.
You'll get a new 100.x IP.

```bash
nixos-generate-config --show-hardware-config --no-filesystems   # compare with hardware.nix
```

Restore files from Sirius (mounted by hand until secrets are set up):

```bash
sudo mkdir -p /mnt/sirius/Kirpal_Share
sudo mount -t cifs //192.168.1.134/Kirpal_Share /mnt/sirius/Kirpal_Share \
  -o username=kirpal,uid=1000,gid=100,vers=3.0,mfsymlinks
rsync -rlt --info=progress2 /mnt/sirius/Kirpal_Share/neptune_home/ ~/
chmod 700 ~/.ssh ~/.gnupg
```

## 5. Secrets (Sirius password)

Secrets are encrypted with [sops](https://github.com/getsops/sops) to two age
keys: yours (to edit) and the machine's SSH host key (to decrypt at boot).
The encrypted file is safe to commit publicly.

```bash
# 1. Your personal key — back up keys.txt somewhere safe (password manager)
mkdir -p ~/.config/sops/age
age-keygen -o ~/.config/sops/age/keys.txt        # prints "Public key: age1..."

# 2. The machine's key
ssh-to-age < /etc/ssh/ssh_host_ed25519_key.pub   # prints age1...

# 3. Put both public keys into .sops.yaml (replace the placeholders), then:
cd ~/Documents/homebase
sops hosts/neptune/secrets.yaml
#    add:   sirius:
#             password: <your NAS password>

# 4. Flakes only see tracked files
git add .sops.yaml hosts/neptune/secrets.yaml
nh os switch .
```

The Sirius mount then appears at `/mnt/sirius/Kirpal_Share` on first access.

## Day to day

```bash
nh os switch .            # rebuild (shows a diff of what changed)
nix flake update          # update everything, then switch
sar -d                    # disk write history — keep an eye on SSD wear
sudo smartctl -a /dev/disk/by-id/nvme-WD_BLACK_SN770_2TB_220734800566
```

Not in nixpkgs, install by hand: `harbor`, `hashcards` (uv/cargo), `magic-trace`,
rustup toolchains (`rustup toolchain install ...`), Zotero
(`flatpak install flathub org.zotero.Zotero`).
