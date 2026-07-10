# NixOS Configuration

A modular, reproducible NixOS system configuration using **Nix Flakes** and **Home Manager**.

---

## Table of Contents

- [Directory Structure](#directory-structure)
- [Core Concepts](#core-concepts)
  - [Flakes](#flakes)
  - [Home Manager](#home-manager)
  - [The Module System](#the-module-system)
- [File Reference](#file-reference)
  - [flake.nix](#flakenix)
  - [hosts/](#hosts)
  - [modules/](#modules)
  - [home/](#home)
- [How to Apply Changes](#how-to-apply-changes)
- [Common Operations](#common-operations)
- [Extending the Config](#extending-the-config)
  - [Adding a System Package](#adding-a-system-package)
  - [Adding a User Package](#adding-a-user-package)
  - [Adding a New Module](#adding-a-new-module)
  - [Configuring a Program with Home Manager](#configuring-a-program-with-home-manager)
  - [Adding a Second Machine](#adding-a-second-machine)
  - [Adding Secrets Management](#adding-secrets-management)
- [Upgrading NixOS](#upgrading-nixos)
- [Rollbacks](#rollbacks)
- [Useful Nix Commands](#useful-nix-commands)

---

## Directory Structure

```
nixos-config/
├── flake.nix                        # Entry point — inputs, outputs, machine definitions
├── flake.lock                       # Auto-generated; pins every input to an exact commit
├── README.md                        # This file
│
├── hosts/
│   └── nixos/                       # Configuration for the machine named "nixos"
│       ├── default.nix              # Host-specific settings: hostname, users, packages
│       └── hardware-configuration.nix  # Auto-generated hardware/filesystem/kernel config
│
├── modules/
│   ├── system/                      # OS-level concerns
│   │   ├── boot.nix                 # Bootloader (systemd-boot, EFI)
│   │   ├── networking.nix           # NetworkManager
│   │   ├── locale.nix               # Timezone, language, locale variables
│   │   ├── audio.nix                # PipeWire audio stack
│   │   └── printing.nix             # CUPS printing
│   └── desktop/
│       └── plasma.nix               # KDE Plasma 6, SDDM, X11, keyboard layout
│
└── home/
    └── tushar.nix                   # Home Manager config for user "tushar"
```

---

## Core Concepts

### Flakes

A **flake** is a self-contained Nix project with explicitly declared inputs and outputs.

Before flakes, NixOS used *channels* — a global, mutable pointer to a nixpkgs version that could silently change between builds. Flakes replace this with a `flake.lock` file that pins every input (nixpkgs, home-manager, etc.) to an exact git commit. This means:

- Two machines built from the same `flake.lock` are **bit-for-bit identical**
- You can reproduce any past system state by checking out an old `flake.lock`
- Updates are explicit: you run `nix flake update` and commit the result

The `flake.nix` file has two sections:

```
inputs  →  what external repos/packages this config depends on
outputs →  what this config produces (NixOS systems, packages, etc.)
```

### Home Manager

**Home Manager** manages everything inside a user's home directory declaratively — dotfiles, user packages, shell config, editor config, and more.

Without Home Manager, user-level config lives in either `configuration.nix` (mixed with system config) or in hand-edited dotfiles (not reproducible). Home Manager solves both problems:

- User packages are declared in `home/tushar.nix`, not in the system config
- Dotfiles for programs like git, zsh, vim, etc. are generated from Nix expressions
- `home-manager switch` applies user changes without needing `sudo`
- The entire home environment is reproducible and version-controlled

Home Manager is integrated here as a NixOS module (via `home-manager.nixosModules.home-manager`), so a single `sudo nixos-rebuild switch` applies both system and home changes together.

### The Module System

NixOS is built on a **module system** — every `.nix` file that looks like `{ config, pkgs, lib, ... }: { ... }` is a module. Modules declare options and configuration values that NixOS merges together into one final system definition.

This config uses the module system to split concerns:

- Each file in `modules/` owns one concern (audio, boot, locale, etc.)
- Modules are imported into a host via its `imports = [ ... ]` list
- NixOS merges all imported modules; there are no conflicts as long as you don't set the same option twice with incompatible values

You can make modules **opt-in** using `lib.mkEnableOption` — see [Adding a New Module](#adding-a-new-module).

---

## File Reference

### `flake.nix`

The root of the entire config. Defines:

- **`inputs.nixpkgs`** — the NixOS package set, pinned to `nixos-unstable`
- **`inputs.home-manager`** — the Home Manager project, pinned and set to follow the same nixpkgs so there's no version mismatch
- **`outputs.nixosConfigurations.nixos`** — the NixOS system named `nixos` (matches the hostname). To add a second machine, add another entry here.

To change the nixpkgs channel (e.g., switch from `nixos-unstable` to `nixos-26.05`), edit the `url` in `inputs.nixpkgs`.

### `hosts/`

Each subdirectory is one machine. The directory name matches the NixOS configuration name used in `flake.nix` and the `--flake` flag.

**`hosts/nixos/default.nix`** — the host manifest. It:
- Imports all modules via `imports = [ ... ]`
- Sets host-specific values: hostname, user accounts, system packages, unfree allowance
- Enables flakes via `nix.settings.experimental-features`
- Sets `system.stateVersion` (do not change this after first install)

**`hosts/nixos/hardware-configuration.nix`** — auto-generated by `nixos-generate-config`. Declares kernel modules, filesystem UUIDs, swap devices, and CPU microcode. Do not edit this by hand. Regenerate it with:

```bash
sudo nixos-generate-config --show-hardware-config > hosts/nixos/hardware-configuration.nix
```

### `modules/`

Reusable, single-concern configuration files. None of them are host-specific — a module added here can be imported by any host.

| File | What it configures |
|------|--------------------|
| `system/boot.nix` | systemd-boot bootloader, EFI variables |
| `system/networking.nix` | NetworkManager |
| `system/locale.nix` | Timezone (`America/Chicago`), `en_US.UTF-8` locale for all `LC_*` variables |
| `system/audio.nix` | PipeWire with ALSA and PulseAudio compatibility; rtkit for real-time scheduling |
| `system/printing.nix` | CUPS print service |
| `modules/desktop/plasma.nix` | KDE Plasma 6 desktop, SDDM display manager, X11 server, US keyboard layout |

### `home/`

Home Manager configurations, one file per user.

**`home/tushar.nix`** — declares:
- `home.username` and `home.homeDirectory` — required by Home Manager
- `home.stateVersion` — like `system.stateVersion`, set once and never change
- `home.packages` — user-scoped packages (currently: `kdePackages.kate`)
- `programs.home-manager.enable` — lets Home Manager manage itself

Everything you would normally put in a dotfile (`.gitconfig`, `.zshrc`, `init.vim`, etc.) can instead be declared here as a Nix expression.

---

## How to Apply Changes

All commands are run from any directory — the `--flake` path tells NixOS where to find the config.

**Test without applying (safe):**
```bash
sudo nixos-rebuild dry-activate --flake ~/nixos-config#nixos
```

**Apply to the running system:**
```bash
sudo nixos-rebuild switch --flake ~/nixos-config#nixos
```

**Build without switching (creates a `./result` symlink to inspect):**
```bash
nixos-rebuild build --flake ~/nixos-config#nixos
```

**Apply on next boot only:**
```bash
sudo nixos-rebuild boot --flake ~/nixos-config#nixos
```

After applying, commit the changes including `flake.lock` so the exact state is recorded:
```bash
cd ~/nixos-config && git add -A && git commit -m "describe what changed"
```

---

## Common Operations

**Update all flake inputs to their latest commits:**
```bash
cd ~/nixos-config && nix flake update
```
This rewrites `flake.lock`. Review the diff, then run `nixos-rebuild switch` to apply.

**Update a single input (e.g., only home-manager):**
```bash
nix flake update home-manager
```

**Search for a package:**
```bash
nix search nixpkgs ripgrep
```

**Open a temporary shell with a package without installing it:**
```bash
nix shell nixpkgs#ripgrep
```

**Open a development shell defined in a project's flake:**
```bash
nix develop
```

**Check what will change before switching:**
```bash
sudo nixos-rebuild dry-activate --flake ~/nixos-config#nixos 2>&1 | grep "would"
```

**List installed system packages:**
```bash
nix-store -q --references /run/current-system | grep -v "nixos"
```

**Show current system generation and history:**
```bash
nixos-rebuild list-generations
```

---

## Extending the Config

### Adding a System Package

System packages are available to all users. Add them to `environment.systemPackages` in `hosts/nixos/default.nix`:

```nix
environment.systemPackages = with pkgs; [
  git
  vim
  # add new packages here
  neovim
  htop
];
```

### Adding a User Package

User packages are scoped to `tushar` and managed by Home Manager. Add them to `home.packages` in `home/tushar.nix`:

```nix
home.packages = with pkgs; [
  kdePackages.kate
  # add new packages here
  obsidian
  spotify
];
```

### Adding a New Module

Create a new file in `modules/system/` or `modules/desktop/`, then import it in the host.

Example — `modules/system/ssh.nix`:
```nix
{ ... }: {
  services.openssh = {
    enable = true;
    settings.PasswordAuthentication = false;
  };
}
```

Then add it to `hosts/nixos/default.nix`:
```nix
imports = [
  ...
  ../../modules/system/ssh.nix
];
```

For modules you want to toggle per-host, use `mkEnableOption`:
```nix
# modules/system/ssh.nix
{ config, lib, ... }:
let cfg = config.myModules.ssh;
in {
  options.myModules.ssh.enable = lib.mkEnableOption "OpenSSH server";

  config = lib.mkIf cfg.enable {
    services.openssh.enable = true;
    services.openssh.settings.PasswordAuthentication = false;
  };
}
```

Enable it from the host:
```nix
myModules.ssh.enable = true;
```

This pattern lets you share modules across many hosts and turn features on or off per machine.

### Configuring a Program with Home Manager

Home Manager has built-in modules for hundreds of programs that generate correct dotfiles automatically. Add program config to `home/tushar.nix` or split it into `home/programs/<name>.nix`.

**Git:**
```nix
programs.git = {
  enable = true;
  userName = "Tushar Wani";
  userEmail = "tushar.wani@parone.com";
  extraConfig.init.defaultBranch = "main";
};
```

**Zsh with plugins:**
```nix
programs.zsh = {
  enable = true;
  enableAutosuggestions = true;
  syntaxHighlighting.enable = true;
  oh-my-zsh = {
    enable = true;
    theme = "robbyrussell";
    plugins = [ "git" "z" ];
  };
};
```

**Neovim:**
```nix
programs.neovim = {
  enable = true;
  defaultEditor = true;
  vimAlias = true;
  plugins = with pkgs.vimPlugins; [ telescope-nvim nvim-treesitter ];
};
```

**Kitty terminal:**
```nix
programs.kitty = {
  enable = true;
  font.name = "JetBrains Mono";
  font.size = 13;
  settings.background_opacity = "0.95";
};
```

To split programs into separate files, import them from `home/tushar.nix`:
```nix
imports = [
  ./programs/git.nix
  ./programs/zsh.nix
  ./programs/neovim.nix
];
```

### Adding a Second Machine

1. Create `hosts/laptop/default.nix` and `hosts/laptop/hardware-configuration.nix`
2. Add a new output in `flake.nix`:

```nix
outputs = { self, nixpkgs, home-manager, ... }: {
  nixosConfigurations = {
    nixos = nixpkgs.lib.nixosSystem {
      system = "x86_64-linux";
      modules = [ ./hosts/nixos/default.nix ... ];
    };
    laptop = nixpkgs.lib.nixosSystem {
      system = "x86_64-linux";
      modules = [ ./hosts/laptop/default.nix ... ];
    };
  };
};
```

3. Build the laptop config with:
```bash
sudo nixos-rebuild switch --flake ~/nixos-config#laptop
```

Modules in `modules/` are shared across all hosts. Each host imports only what it needs.

### Adding Secrets Management

**sops-nix** is the most common secrets manager for NixOS flakes. It encrypts secrets with your SSH or age key and decrypts them at activation time.

Add it to `flake.nix`:
```nix
inputs.sops-nix = {
  url = "github:Mic92/sops-nix";
  inputs.nixpkgs.follows = "nixpkgs";
};
```

Then add the module and declare secrets:
```nix
imports = [ inputs.sops-nix.nixosModules.sops ];

sops.defaultSopsFile = ./secrets/secrets.yaml;
sops.secrets.wifi_password = {};
```

Secrets are created with `sops secrets/secrets.yaml` and are only readable by the declared owner at runtime.

---

## Upgrading NixOS

To move to a new NixOS release, change the nixpkgs input URL in `flake.nix`:

```nix
# from:
nixpkgs.url = "github:NixOS/nixpkgs/nixos-unstable";
# to a stable release:
nixpkgs.url = "github:NixOS/nixpkgs/nixos-26.11";
```

Also update `system.stateVersion` in `hosts/nixos/default.nix` and `home.stateVersion` in `home/tushar.nix` to match the new release. Then:

```bash
nix flake update
sudo nixos-rebuild switch --flake ~/nixos-config#nixos
```

---

## Rollbacks

Every `nixos-rebuild switch` creates a new **generation** — a snapshot of the complete system. The previous generation is always preserved.

**Roll back to the previous generation immediately:**
```bash
sudo nixos-rebuild switch --rollback
```

**List all generations:**
```bash
sudo nix-env --list-generations --profile /nix/var/nix/profiles/system
```

**Boot into a specific generation** — at the systemd-boot menu, press any key to see the generation list and select a previous one. No commands needed.

**Delete old generations to free disk space:**
```bash
sudo nix-collect-garbage --delete-older-than 14d
sudo nixos-rebuild boot --flake ~/nixos-config#nixos  # update bootloader entries
```

---

## Useful Nix Commands

| Command | Description |
|---------|-------------|
| `nix flake update` | Update all inputs in `flake.lock` |
| `nix flake show` | Show all outputs this flake produces |
| `nix flake check` | Validate the flake for errors |
| `nix search nixpkgs <name>` | Search for a package |
| `nix shell nixpkgs#<pkg>` | Temporary shell with a package |
| `nix store gc` | Run garbage collection |
| `nix store optimise` | Deduplicate the nix store (saves disk) |
| `nixos-rebuild switch --flake .#nixos` | Apply config from current directory |
| `nixos-rebuild dry-activate --flake .#nixos` | Preview changes without applying |
| `nixos-rebuild list-generations` | Show generation history |
| `nix repl` | Interactive Nix expression evaluator |
| `nix-instantiate --eval -E 'import <nixpkgs> {}'` | Evaluate a Nix expression |
