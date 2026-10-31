# home-manager config for kirpal on neptune.
# Shared CLI tools come from modules/dev (same set as the Docker images);
# everything desktop-specific lives here.
{ pkgs, lib, inputs, base, ... }:

let
  # Container coreutils swap is fine in Docker, but keep GNU coreutils on the desktop.
  devTools = builtins.filter (p: !(lib.hasPrefix "uutils" (lib.getName p))) base.packages;

  # Repo zellij config with this machine's tweaks (Wayland clipboard, no tips)
  zellijConfig = builtins.replaceStrings
    [ "// copy_command \"pbcopy\"\n" "// show_startup_tips false" ]
    [ "copy_command \"wl-copy\"\n" "show_startup_tips false" ]
    (builtins.readFile ../dev/zellij/config.kdl);

  # anydoc (firecrawl) is a library only; this gives it a pandoc-style CLI:
  #   anydoc report.docx > report.md      cat slides.pptx | anydoc
  anydoc = pkgs.writers.writePython3Bin "anydoc"
    { libraries = [ pkgs.python3Packages.firecrawl-anydoc ]; }
    ''
      import sys

      import anydoc

      for path in sys.argv[1:] or ["-"]:
          if path == "-":
              data = sys.stdin.buffer.read()
              sys.stdout.write(anydoc.to_markdown_bytes(data))
          else:
              sys.stdout.write(anydoc.to_markdown(path))
    '';
in
{
  imports = [
    inputs.nix-index-database.homeModules.nix-index
    inputs.cosmic-manager.homeManagerModules.cosmic-manager
  ];

  home.stateVersion = "26.11";

  # starship.toml etc. from modules/dev; fish and zellij are handled below
  xdg.configFile = builtins.removeAttrs base.configFiles [ "fish/config.fish" "zellij/config.kdl" ]
    // { "zellij/config.kdl".text = zellijConfig; };

  home.sessionPath = [
    "$HOME/.cargo/bin"
    "$HOME/.local/bin"
    "$HOME/bin"
    "$HOME/.elan/bin"
  ];

  # ── Shell ─────────────────────────────────────────────
  programs.fish = {
    enable = true;
    shellAliases = {
      ls = "eza";
      find = "fd";
      du = "dust";
      zj = "zellij";
      tunnel = "code tunnel";
    };
  };
  programs.starship.enable = true; # reads ~/.config/starship.toml from the repo
  programs.direnv = {
    enable = true;
    nix-direnv.enable = true; # `use flake` in .envrc, cached
  };
  programs.zoxide.enable = true; # `z <dir>`
  programs.nix-index.enable = true;
  programs.nix-index-database.comma.enable = true; # `, <cmd>` runs without installing

  programs.helix = {
    enable = true;
    settings.editor.default-yank-register = "+"; # y/p use the system clipboard
  };

  # ── Terminal: Alacritty, opens straight into zellij ──
  programs.alacritty = {
    enable = true;
    theme = "hyper";
    settings = {
      font.size = 14;
      font.normal.family = "Hack Nerd Font";
      selection.save_to_clipboard = true;
      terminal.shell.program = "zellij";
    };
  };

  # ── COSMIC desktop (cosmic-manager) ───────────────────
  wayland.desktopManager.cosmic = {
    enable = true;

    # COSMIC's "Terminal" action (Super+T by default) opens Alacritty
    systemActions = {
      __type = "map";
      value = [
        {
          key = { __type = "enum"; variant = "Terminal"; };
          value = "alacritty";
        }
      ];
    };

    # Ubuntu habits: Ctrl+Alt+T for a terminal, Ctrl+Alt+1-4 for workspaces
    shortcuts =
      [
        {
          key = "Ctrl+Alt+T";
          action = {
            __type = "enum";
            variant = "System";
            value = [ { __type = "enum"; variant = "Terminal"; } ];
          };
        }
      ]
      ++ map (n: {
        key = "Ctrl+Alt+${toString n}";
        action = { __type = "enum"; variant = "Workspace"; value = [ n ]; };
      }) [ 1 2 3 4 ];
  };

  # ── One clipboard ─────────────────────────────────────
  # Wayland has two: CLIPBOARD (Ctrl+C) and PRIMARY (select / middle-click).
  # This copies every selection into CLIPBOARD so there's effectively one,
  # and keeps a history (`cliphist list`).
  systemd.user.services = {
    clipboard-unify = {
      Unit.Description = "Copy PRIMARY selection into CLIPBOARD";
      Unit.PartOf = [ "graphical-session.target" ];
      Unit.After = [ "graphical-session.target" ];
      Service.ExecStart = "${pkgs.wl-clipboard}/bin/wl-paste --primary --watch ${pkgs.wl-clipboard}/bin/wl-copy";
      Service.Restart = "on-failure";
      Install.WantedBy = [ "graphical-session.target" ];
    };
  };
  services.cliphist.enable = true;

  # ── Git + signing ─────────────────────────────────────
  programs.git = {
    enable = true;
    lfs.enable = true;
    signing = {
      key = "4CD24B8702F76476";
      signByDefault = true;
    };
    ignores = [ "/target" "/.idea" "/.vscode" "**/.claude/settings.local.json" ];
    settings = {
      user.name = "Kirpal Grewal";
      user.email = "kirpal@outlook.com";
      init.defaultBranch = "master";
    };
  };
  programs.gpg.enable = true;
  services.gpg-agent = {
    enable = true;
    pinentry.package = pkgs.pinentry-gnome3;
  };

  # ── Packages ──────────────────────────────────────────
  home.packages = devTools ++ (with pkgs; [
    # Rust: rustup keeps per-project rust-toolchain.toml working
    rustup
    cargo-nextest
    cargo-watch
    cargo-expand
    # tests fail in nixpkgs (rustc/LLVM profraw version mismatch); the tool itself is fine
    (cargo-llvm-cov.overrideAttrs { doCheck = false; })
    cargo-flamegraph
    cargo-binstall
    cargo-udeps
    cargo-audit
    cargo-release
    cargo-make
    cargo-generate
    cargo-bloat
    cargo-dist
    cargo-cross
    cargo-fuzz
    cargo-tarpaulin
    cargo-vet
    cargo-update
    cargo-show-asm
    cargo-geiger
    cargo-lambda
    cargo-pgo
    cargo-rdme
    cargo-shuttle
    cargo-wizard
    cargo-auditable
    cargo-clean-recursive
    oranda
    kondo # clean old target/ dirs
    buck2
    trunk
    dioxus-cli
    wasmtime
    wabt

    # AI / Python tools (were uv tools)
    claude-code
    pre-commit
    pyrefly
    ty
    vastai
    python3Packages.wandb
    fortls

    # Shell / TUI
    nushell
    yazi
    typst
    tickrs
    dysk
    asciinema
    gitoxide
    jq

    # Build / C / Fortran
    gfortran # also provides gcc/g++
    (lib.setPrio 20 clang) # gfortran wrapper is already lowPrio (10); clang must be lower still or bin/cc conflicts
    lld
    mold
    cmake
    ninja
    gnumake
    pkg-config
    protobuf
    bazel_7
    autoconf
    bison
    flex
    gdb

    # Other languages
    go
    gopls
    go-tools # staticcheck
    ghc
    cabal-install
    stack
    haskell-language-server
    elan # Lean 4
    opam
    dotnet-sdk_8
    jdk17
    nodejs # current LTS (20 is EOL)

    # Science / docs
    texliveFull
    anydoc # docs → markdown (replaces pandoc)
    gnuplot
    graphviz
    imagemagick
    ffmpeg
    qemu
    pdfpc
    (lib.lowPrio cudaPackages.cudatoolkit) # bundles cuda-gdb data files that clash with gdb

    # Nix tooling
    devenv
    nix-output-monitor
    nvd

    # Network
    iperf3
    speedtest-cli

    # Desktop apps
    vscode
    zed-editor
    firefox
    google-chrome
    thunderbird
    slack
    zoom-us
    zulip
    # zotero: nixpkgs build needs an insecure firefox-esr; use `flatpak install flathub org.zotero.Zotero`
    spotify
    gimp
    vlc
    libreoffice
    kdePackages.okular
    xournalpp
    texstudio
    remmina
    dbeaver-bin
    unityhub
    synology-drive-client
  ]);
}
