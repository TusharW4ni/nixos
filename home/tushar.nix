{ pkgs, inputs, config, ... }:
let
  nixos-switch = pkgs.writeShellScriptBin "nixos-switch" ''
    set -e
    CONFIG_DIR="$HOME/nixos-config"

    cd "$CONFIG_DIR"

    # `nixos-switch --update` bumps all flake inputs before rebuilding. Any
    # other flags are passed through to nixos-rebuild untouched.
    if [ "$1" = "--update" ] || [ "$1" = "-u" ]; then
      shift
      nix flake update
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

    sudo nixos-rebuild switch --flake "$CONFIG_DIR#nixos-vivobook" "$@"

    if [ -n "$COMMITTED" ]; then
      GENERATION=$(sudo nix-env --list-generations --profile /nix/var/nix/profiles/system | tail -1 | awk '{print $1}')
      git commit -q --amend -m "switch: generation $GENERATION ($(date '+%Y-%m-%d %H:%M'))"
      git push origin main
    else
      echo "nixos-switch: nothing new to commit"
    fi
  '';
in
{
  imports = [
    inputs.plasma-manager.homeModules.plasma-manager
    inputs.nixvim.homeModules.nixvim
    ./plasma.nix
    ./hyprland.nix
    # nixvim config sourced from the nvim repo's nixvim branch (see flake input)
    "${inputs.nvim-config}/nvim.nix"
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
    kdePackages.kdenlive
    kdePackages.kate
    nixos-switch
    # Neovim itself is provided by nixvim (see ./nvim.nix). ripgrep/fd stay
    # here for interactive shell use (nixvim also puts them on nvim's PATH).
    jq
    ripgrep
    fd
    cmatrix
    unzip
    timg
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
    ghostty
    obsidian
    freecad
    blender
    # AWS CLI v2. `aws configure`/`aws sso login` write creds to ~/.aws, which
    # is outside the Nix store and persists across rebuilds.
    awscli2
    # Bun runtime. Lets `bunx`/`bun add -g` run npm-published TUIs & tools
    # through a nix-patched runtime, avoiding the `curl | sh` prebuilt-binary
    # dynamic-linker breakage on NixOS.
    bun
    # Node.js 24 "Krypton" (current LTS), nix-patched so its binary runs
    # natively on NixOS. Provides `node`/`npm`/`npx` on PATH — needed by node
    # CLI tools and by the caveman plugin's hooks (which call a bare `node`).
    nodejs_24
    inputs.herdr.packages.${pkgs.stdenv.hostPlatform.system}.default
    # Source-built from pkgs/claude-sync.nix (bump version there to update;
    # `claude-sync update` can't self-update the read-only Nix store).
    (pkgs.callPackage ../pkgs/claude-sync.nix { })
    # pi coding agent. Also the harness behind treechat.nvim (pi --mode rpc).
    # API keys live in ~/.pi/agent (run `pi`, then /login), outside the store.
    pi-coding-agent
  ];

  # treechat.nvim: tree-shaped LLM chats on top of pi. Loaded from the local
  # dev checkout so edits apply on nvim restart without a rebuild; skipped
  # when the checkout isn't there.
  # Renders markdown (code blocks, headings, bullets, tables) in the treechat
  # transcript only; its buffer uses filetype "treechat", so regular .md files
  # are unaffected.
  programs.nixvim.plugins.render-markdown = {
    enable = true;
    settings = {
      file_types = [ "treechat" ];
      # Groups defined by treechat: faint block shade, no inline-code background.
      code = {
        highlight = "TreechatCode";
        highlight_inline = "TreechatCodeInline";
      };
    };
  };
  programs.nixvim.extraConfigLua = ''
    local treechat_dir = vim.fn.expand("~/p/treechat.nvim")
    if vim.fn.isdirectory(treechat_dir) == 1 then
      vim.opt.rtp:prepend(treechat_dir)
      require("treechat").setup({})
    end
  '';

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

  nix.gc = {
    automatic = true;
    dates = "weekly";
    options = "--delete-older-than 14d";
  };

  programs.bash.enable = true;
  # claude-code is a system package (hosts/nixos-vivobook/default.nix:41), so `claude`
  # is always on PATH — no `command -v` guard needed. These land via
  # shellAliases, which home-manager writes AFTER bash's interactive guard;
  # bashrcExtra ran at the very top of .bashrc, before PATH was ready, so the
  # guard could fail and the aliases silently vanish.
  #   c  -> claude (auto mode)
  #   cw -> claude in a fresh git worktree (auto mode; accepts an optional name)
  #   ponder -> headless ponder-skill loop: ponder [repo] [sleep-seconds]
  programs.bash.shellAliases = {
    ns = "nixos-switch";
    c = "claude --permission-mode auto";
    cw = "claude --permission-mode auto --worktree";
    ponder = "~/.claude/skills/ponder/scripts/ponder.sh";
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
  '';

  # Auto-enter a project's dev shell on cd (reads .envrc → `use flake`).
  # nix-direnv caches the shell so re-entry is instant.
  programs.direnv = {
    enable = true;
    nix-direnv.enable = true;
  };
}
