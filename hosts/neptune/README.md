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

3. **Push this branch** so the installer can clone it (commits are GPG-signed):

   ```bash
   cd ~/Documents/homebase
   git add -A
   git commit -m "neptune: NixOS desktop config"
   git push -u origin neptune
   ```

## 1. Make the install USB

No custom ISO is needed — the official one installs this flake directly.

```bash
cd ~/Documents/sirius/Kirpal_Share
ISO=latest-nixos-minimal-x86_64-linux.iso
curl -LO https://channels.nixos.org/nixos-unstable/$ISO
curl -L https://channels.nixos.org/nixos-unstable/$ISO.sha256 | sha256sum -c
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

2. Get the config:

   ```bash
   nix-shell -p git
   git clone -b neptune https://github.com/KGrewal1/homebase
   cd homebase
   ```

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

6. Copy the repo onto the new system so it's there after reboot, then reboot:

   ```bash
   sudo mkdir -p /mnt/home/kirpal/Documents
   sudo cp -r ~/homebase /mnt/home/kirpal/Documents/
   sudo nixos-enter --root /mnt -c 'chown -R kirpal:users /home/kirpal/Documents'
   reboot
   ```

## 4. First boot

```bash
sudo tailscale up --ssh
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
