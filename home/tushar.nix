{ pkgs, lib, inputs, config, ... }:
let
  nixos-switch = pkgs.writeShellScriptBin "nixos-switch" ''
    set -eo pipefail
    CONFIG_DIR="$HOME/nixos-config"

    cd "$CONFIG_DIR"

    # `nixos-switch --update [input...]` bumps the named flake inputs (all of
    # them when none are named) before rebuilding. Any other flags are passed
    # through to nixos-rebuild untouched.
    if [ "$1" = "--update" ] || [ "$1" = "-u" ]; then
      shift
      inputs=()
      while [ $# -gt 0 ] && [ "''${1#-}" = "$1" ]; do inputs+=("$1"); shift; done
      nix flake update "''${inputs[@]}"
    fi

    # Commit BEFORE the sudo rebuild so Nix hashes a CLEAN tree. Rebuilding
    # against a dirty tree makes Nix (running as root) write root-owned
    # objects into .git/objects, which then break later user-level git/nix
    # operations. Commit provisionally, then amend with the generation number.
    if [ -n "$(git status --porcelain)" ]; then
      git add -A
      git --no-pager diff --cached
      git commit -q -m "switch: pending ($(date '+%Y-%m-%d %H:%M'))"
      COMMITTED=1
    fi

    # Prompt for the password now: once nom owns the screen it paints over
    # sudo's prompt and the switch looks hung.
    sudo -v

    # nom (nix-output-monitor) draws the build as a live dependency tree.
    sudo nixos-rebuild switch --flake "$CONFIG_DIR#nixos-vivobook" \
      --log-format internal-json -v "$@" |& ${pkgs.nix-output-monitor}/bin/nom --json

    if [ -n "$COMMITTED" ]; then
      GENERATION=$(sudo nix-env --list-generations --profile /nix/var/nix/profiles/system | tail -1 | awk '{print $1}')
      git commit -q --amend -m "switch: generation $GENERATION ($(date '+%Y-%m-%d %H:%M'))"
      git push origin main
    else
      echo "nixos-switch: nothing new to commit"
    fi
  '';
  # `devices [url]` opens the app as an iPhone and an iPad (WebKit, the engine
  # Safari uses) plus a desktop Chrome window, all against one dev server.
  # Each device keeps its own login in ~/.local/state/devices.
  devices = pkgs.writeShellScriptBin "devices" ''
    URL="''${1:-http://localhost:3000}"
    STATE="$HOME/.local/state/devices"
    mkdir -p "$STATE"
    open_device() {
      local name="$1" file="$STATE/$2.json"
      [ -s "$file" ] || echo '{"cookies":[],"origins":[]}' > "$file"
      ${pkgs.playwright-test}/bin/playwright open -b webkit --device="$name" \
        --load-storage="$file" --save-storage="$file" "$URL" &
    }
    open_device "iPhone 15 Pro" iphone
    open_device "iPad Pro 11" ipad
    google-chrome-stable --new-window "$URL" >/dev/null 2>&1 &
    wait
  '';
  # Every Claude Code session gets its own systemd scope in claude.slice
  # (below). The slice's low CPU weight keeps the desktop responsive when
  # sessions max out the CPU, and under memory pressure systemd-oomd kills
  # the single worst session instead of the whole Ghostty window. Shadows the
  # system claude-code package, which comes later on PATH.
  claude = pkgs.writeShellScriptBin "claude" ''
    real=/run/current-system/sw/bin/claude
    # No user systemd bus (e.g. a bare TTY): run it directly.
    [ -S "''${XDG_RUNTIME_DIR:-/nonexistent}/bus" ] || exec "$real" "$@"
    exec ${pkgs.systemd}/bin/systemd-run --user --scope --quiet --collect --slice=claude.slice -- "$real" "$@"
  '';
in
{
  imports = [
    ./omp.nix
    inputs.hex.homeManagerModules.default
    inputs.nixvim.homeModules.nixvim
    ./nvim.nix
  ];

  home.username = "tushar";
  home.homeDirectory = "/home/tushar";
  home.stateVersion = "26.05";

  # `bun add -g` drops binaries (e.g. hntui) into ~/.bun/bin. The tools
  # themselves are imperative/mutable, but keeping this on PATH declaratively
  # means they're runnable by name once installed.
  # ~/.local/bin: upstream `curl | bash` installers (e.g. terminal-browser)
  # drop wrapper scripts here. Like ~/.bun/bin, the binaries are imperative;
  # keeping the dir on PATH declaratively makes them runnable by name.
  home.sessionPath = [ "$HOME/.bun/bin" "$HOME/.local/bin" ];

  home.packages = with pkgs; [
    claude # scope wrapper (above)
    nixos-switch
    nix-output-monitor # `nom build`, `nom develop`, `nom shell` for ad-hoc builds
    devices
    # Playwright CLI wired to nixpkgs' own browsers (incl. WebKit); the
    # browsers Playwright downloads itself don't run on NixOS.
    playwright-test
    # Neovim itself is provided by nixvim (see ./nvim.nix). ripgrep/fd stay
    # here for interactive shell use (nixvim also puts them on nvim's PATH).
    jq
    ripgrep
    fd
    cmatrix
    unzip
    timg
    ffmpeg
    # C/C++ toolchain: clang (also provides cc/c++) plus clangd,
    # clang-format and clang-tidy from clang-tools.
    clang
    clang-tools
    # Wayland clipboard provider. Required for nvim's clipboard=unnamedplus
    # (the `+` register) — without it c/cw/y/d error on every op.
    wl-clipboard
    # python3: required by Claude Code plugin hooks (e.g. yap-with-claude)
    # that shell out to `python3`; macOS ships it, NixOS does not.
    python3
    discord
    slack
    obsidian
    (anki.withAddons [ ankiAddons.anki-connect ])
    freecad
    blender
    # AWS CLI v2. `aws configure`/`aws sso login` write creds to ~/.aws, which
    # is outside the Nix store and persists across rebuilds.
    awscli2
    # Bitwarden CLI (`bw`); also the backend the Bitwarden MCP server shells out to.
    bitwarden-cli
    # Bun runtime. Lets `bunx`/`bun add -g` run npm-published TUIs & tools
    # through a nix-patched runtime, avoiding the `curl | sh` prebuilt-binary
    # dynamic-linker breakage on NixOS.
    bun
    # Node.js 24 "Krypton" (current LTS), nix-patched so its binary runs
    # natively on NixOS. Provides `node`/`npm`/`npx` on PATH — needed by node
    # CLI tools and by the caveman plugin's hooks (which call a bare `node`).
    nodejs_24
    inputs.herdr.packages.${pkgs.stdenv.hostPlatform.system}.default
    inputs.collie.packages.${pkgs.stdenv.hostPlatform.system}.collie
    # Source-built from pkgs/claude-sync.nix (bump version there to update;
    # `claude-sync update` can't self-update the read-only Nix store).
    (pkgs.callPackage ../pkgs/claude-sync.nix { })
    # Slack TUI, source-built from pkgs/slk.nix.
    (pkgs.callPackage ../pkgs/slk.nix { })
    # pi coding agent. Also the harness behind treechat.nvim (pi --mode rpc).
    # API keys live in ~/.pi/agent (run `pi`, then /login), outside the store.
    pi-coding-agent
  ];

  xdg.configFile."herdr/config.toml".source = ./herdr.toml;

  programs.home-manager.enable = true;

  xdg.desktopEntries.ghostty = {
    name = "Ghostty";
    exec = "ghostty";
    terminal = false;
    categories = [ "System" "TerminalEmulator" ];
  };

  programs.git = {
    enable = true;
    settings.user.name = "TusharW4ni";
    settings.user.email = "reachtusharwani@gmail.com";
    settings.user.signingkey = "${config.home.homeDirectory}/.ssh/id_ed25519.pub";
    settings.gpg.format = "ssh";
    settings.gpg.ssh.allowedSignersFile =
      "${config.home.homeDirectory}/.ssh/allowed_signers";
    settings.commit.gpgsign = true;
    settings.tag.gpgsign = true;
  };

  programs.gh = {
    enable = true;
    settings.git_protocol = "https";
    gitCredentialHelper.enable = true;
    extensions = [ pkgs.gh-dash ];
  };

  programs.lazygit.enable = true;

  # Hex local voice dictation (github:anomalyco/hex). The module installs the
  # package and runs `hex service` as a systemd user service bound to
  # graphical-session.target (active under both Hyprland and Plasma here).
  # installModel downloads the selected transcription model from a one-shot
  # user service once the network is up; drop it to install the model by hand
  # with `hex model install`.
  programs.hex = {
    enable = true;
    autostart = true;
    installModel = true;
    # Hyprland ignores this key (its GlobalShortcuts portal grants the
    # shortcut without one; the real bind is in home/hypr/main.lua). Kept in
    # sync so Hex's Settings shows the key that actually dictates.
    shortcut = "ctrl+shift+space";
  };

  nix.gc = {
    automatic = true;
    dates = "weekly";
    options = "--delete-older-than 14d";
  };

  # Claude Code sessions (see the claude wrapper above). CPUWeight is
  # relative to the desktop apps' 100: under contention they get 5x the CPU.
  systemd.user.slices.claude = {
    Unit.Description = "Claude Code sessions";
    Slice = {
      CPUWeight = 20;
      ManagedOOMMemoryPressure = "kill";
      ManagedOOMMemoryPressureLimit = "60%";
    };
  };

  programs.bash.enable = true;
  # claude-code is a system package (hosts/nixos-vivobook/default.nix:41), so `claude`
  # is always on PATH — no `command -v` guard needed. These land via
  # shellAliases, which home-manager writes AFTER bash's interactive guard;
  # bashrcExtra ran at the very top of .bashrc, before PATH was ready, so the
  # guard could fail and the aliases silently vanish.
  #   c  -> claude (auto mode)
  #   cw -> claude in a fresh git worktree (auto mode; accepts an optional name)
  #   n  -> nvim . with no argument, nvim <args> otherwise
  #   ghe -> gh issue view
  #   o  -> omp (see ./omp.nix)
  #   ponder -> headless ponder-skill loop: ponder [repo] [sleep-seconds]
  programs.bash.shellAliases = {
    ns = "nixos-switch";
    c = "claude --permission-mode auto";
    cw = "claude --permission-mode auto --worktree";
    o = "omp";
    ponder = "~/.claude/skills/ponder/scripts/ponder.sh";
    yazi = "y"; # the y wrapper cds into yazi's last directory on exit
    "..." = "cd ../..";
    "...." = "cd ../../..";
    ava = "cd ~/w/app.avagolf.com";
    ava-cw = "cd ~/w/app.avagolf.com && cw";
  };

  # claude-sync integration: keep sessions synced with the R2 remote.
  # The config.yaml + age-key.txt are delivered by agenix (see
  # modules/system/secrets.nix); this only decides WHEN to push/pull.
  programs.bash.initExtra = ''
    # Put bun's global-install bin dir (`bun add -g` → ~/.bun/bin) on PATH for
    # interactive shells. home.sessionPath only covers LOGIN shells via
    # hm-session-vars.sh — and that file self-guards with __HM_SESS_VARS_SOURCED,
    # which existing desktop sessions already carry, so re-sourcing is a no-op.
    # Set it directly here instead; the case guard keeps it idempotent.
    case ":$PATH:" in
      *":$HOME/.bun/bin:"*) ;;
      *) export PATH="$HOME/.bun/bin:$PATH" ;;
    esac

    # Same deal for ~/.local/bin, where `curl | bash` installers drop wrappers.
    case ":$PATH:" in
      *":$HOME/.local/bin:"*) ;;
      *) export PATH="$HOME/.local/bin:$PATH" ;;
    esac

    # TODO(human): decide the auto-sync trigger and fill this in.

    # n -> nvim . with no argument, nvim <args> otherwise (aliases can't
    # branch on $#, so this is a function). Definition doesn't need `nvim`
    # on PATH — it's resolved at call time.
    n() {
      if [ "$#" -eq 0 ]; then
        nvim .
      else
        nvim "$@"
      fi
    }

    # ghe -> view a GitHub issue in a readonly nvim buffer (gh issue view
    # prints markdown; `gh issue view 42 --comments` also works).
    # NB: the `-` (read stdin) must come BEFORE the -c commands, otherwise
    # nvim opens an empty buffer (verified with --headless, 2026-06).
    ghe() {
      gh issue view "$@" | nvim -R - -c 'set ft=markdown buftype=nofile'
    }
  '';

  # Auto-enter a project's dev shell on cd (reads .envrc → `use flake`).
  # nix-direnv caches the shell so re-entry is instant.
  programs.direnv = {
    enable = true;
    nix-direnv.enable = true;
  };
}
