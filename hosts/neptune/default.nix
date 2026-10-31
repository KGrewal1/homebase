{ inputs, config, lib, pkgs, ... }:

let
  base = import ../../packages/packages.nix { inherit pkgs lib; };

  # Secrets are optional until hosts/neptune/secrets.yaml exists (see README).
  # Flakes only see git-tracked files, so `git add` it after creating it.
  hasSecrets = builtins.pathExists ./secrets.yaml;
in
{
  imports = [
    inputs.disko.nixosModules.disko
    inputs.sops-nix.nixosModules.sops
    ./disko.nix
    ./hardware.nix
    ../../modules/nixos/cosmic.nix
    ../../modules/nixos/nvidia.nix
    ../../modules/nixos/tailscale.nix
  ] ++ lib.optionals hasSecrets [
    ../../modules/nixos/sirius.nix
  ];

  networking.hostName = "neptune";
  networking.networkmanager.enable = true;

  # ── Boot ──────────────────────────────────────────────
  boot.loader.systemd-boot.enable = true;
  boot.loader.systemd-boot.configurationLimit = 20;
  boot.loader.efi.canTouchEfiVariables = true;

  # ── Locale ────────────────────────────────────────────
  time.timeZone = "Europe/London";
  i18n.defaultLocale = "en_GB.UTF-8";
  console.keyMap = "uk";
  services.xserver.xkb.layout = "gb";

  # Chinese input (replaces the old ibus cangjie/chewing/pinyin setup)
  i18n.inputMethod = {
    enable = true;
    type = "fcitx5";
    fcitx5.waylandFrontend = true;
    fcitx5.addons = with pkgs; [
      qt6Packages.fcitx5-chinese-addons # pinyin
      fcitx5-chewing
      fcitx5-table-extra # cangjie
    ];
  };

  # Nerd Fonts carry the glyphs starship/eza/yazi/zellij draw
  fonts.packages = with pkgs; [
    nerd-fonts.ubuntu-mono # current gnome-terminal font
    nerd-fonts.hack # current Alacritty font
    nerd-fonts.jetbrains-mono
    nerd-fonts.symbols-only # icon fallback for non-Nerd fonts
    noto-fonts
    noto-fonts-cjk-sans
    noto-fonts-color-emoji
  ];
  fonts.fontconfig.defaultFonts = {
    monospace = [ "UbuntuMono Nerd Font" "Symbols Nerd Font Mono" ];
    emoji = [ "Noto Color Emoji" ];
  };

  # ── Nix ───────────────────────────────────────────────
  nixpkgs.config.allowUnfree = true;
  nix.settings = {
    experimental-features = [ "nix-command" "flakes" ];
    trusted-users = [ "root" "kirpal" ];
    auto-optimise-store = true;
    extra-substituters = [ "https://nix-community.cachix.org" ];
    extra-trusted-public-keys = [
      "nix-community.cachix.org-1:mB9FSh9qf2dCimDSUo8Zy7bkq5CX+/rkCWyvRCYg3Fs="
    ];
  };
  nix.gc = {
    automatic = true;
    dates = "weekly";
    options = "--delete-older-than 14d";
  };
  programs.nh = {
    enable = true; # `nh os switch .` — nicer rebuilds with diffs
    flake = "/home/kirpal/Documents/homebase";
  };

  # Run unpatched binaries: uv pythons, rustup toolchains, VS Code server,
  # ~/bin (GMIN/OPTIM/PATHSAMPLE), claude, etc.
  programs.nix-ld = {
    enable = true;
    libraries = with pkgs; [
      stdenv.cc.cc.lib
      gfortran.cc.lib
      zlib
      zstd
      openssl
      libffi
      xz
      bzip2
      readline
      glib
      libGL
      libxkbcommon
      fontconfig
      freetype
      curl
      icu
    ];
  };

  # ── Users ─────────────────────────────────────────────
  users.users.kirpal = {
    isNormalUser = true;
    uid = 1000;
    description = "Kirpal Grewal";
    extraGroups = [ "wheel" "networkmanager" "docker" "video" "audio" "dialout" ];
    shell = pkgs.fish;
    # Set a password after install: `sudo nixos-enter --root /mnt -c 'passwd kirpal'`
  };
  programs.fish.enable = true;

  home-manager = {
    useGlobalPkgs = true;
    useUserPackages = true;
    backupFileExtension = "hm-bak";
    extraSpecialArgs = { inherit inputs base; };
    users.kirpal = import ../../modules/home/kirpal.nix;
  };

  # ── Secrets (sops-nix, age) ───────────────────────────
  sops = lib.mkIf hasSecrets {
    defaultSopsFile = ./secrets.yaml;
    # The machine decrypts with its own SSH host key, converted to age.
    age.sshKeyPaths = [ "/etc/ssh/ssh_host_ed25519_key" ];
  };

  # ── Services ──────────────────────────────────────────
  services.openssh = {
    enable = true;
    settings.PasswordAuthentication = false;
    settings.PermitRootLogin = "no";
  };

  # `sirius.local` resolution
  services.avahi = {
    enable = true;
    nssmdns4 = true;
  };

  services.printing.enable = true;
  services.fwupd.enable = true;
  services.flatpak.enable = true;
  services.locate.enable = true;
  services.cloudflare-warp.enable = true;
  hardware.logitech.wireless.enable = true;
  programs.solaar.enable = true;

  virtualisation.docker = {
    enable = true;
    autoPrune.enable = true;
  };

  # ── Disk health (the old SSD died of write wear) ─────
  services.smartd = {
    enable = true;
    notifications.wall.enable = true;
  };
  services.sysstat.enable = true; # daily disk-write history: `sar -d`
  services.fstrim.enable = true;
  boot.tmp.useTmpfs = true; # /tmp in RAM (94 GB available)
  boot.tmp.tmpfsSize = "40%";
  zramSwap.enable = true; # compressed swap in RAM, no SSD writes

  environment.systemPackages = with pkgs; [
    git
    vim
    curl
    wget
    pciutils
    usbutils
    smartmontools
    lm_sensors
    sysstat
    iotop
    cifs-utils
    sops
    age
    ssh-to-age
    wl-clipboard
  ];

  system.stateVersion = "26.11"; # release installed with; never change after
}
