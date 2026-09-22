{ pkgs, inputs, ... }:
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
      git commit -m "switch: pending ($(date '+%Y-%m-%d %H:%M'))"
      COMMITTED=1
    fi

    sudo nixos-rebuild switch --flake "$CONFIG_DIR#nixos" "$@"

    if [ -n "$COMMITTED" ]; then
      GENERATION=$(sudo nix-env --list-generations --profile /nix/var/nix/profiles/system | tail -1 | awk '{print $1}')
      git commit --amend -m "switch: generation $GENERATION ($(date '+%Y-%m-%d %H:%M'))"
      git push origin main
    else
      echo "nixos-switch: nothing new to commit"
    fi
  '';
in
{
  imports = [
    inputs.plasma-manager.homeModules.plasma-manager
    ./plasma.nix
  ];

  home.username = "tushar";
  home.homeDirectory = "/home/tushar";
  home.stateVersion = "26.05";

  home.packages = with pkgs; [
    kdePackages.kate
    nixos-switch
    neovim
    discord
    slack
    ghostty
    inputs.herdr.packages.${pkgs.stdenv.hostPlatform.system}.default
    # Source-built from pkgs/claude-sync.nix (bump version there to update;
    # `claude-sync update` can't self-update the read-only Nix store).
    (pkgs.callPackage ../pkgs/claude-sync.nix { })
  ];

  xdg.configFile."herdr/config.toml".source = ./herdr.toml;

  # Neovim config, pinned from github:TusharW4ni/nvim (flake = false input).
  # Update with: nix flake update nvim-config && ns
  xdg.configFile."nvim".source = inputs.nvim-config;

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
  };

  programs.gh = {
    enable = true;
    settings.git_protocol = "https";
    gitCredentialHelper.enable = true;
  };

  nix.gc = {
    automatic = true;
    dates = "weekly";
    options = "--delete-older-than 14d";
  };

  programs.bash.enable = true;
  programs.bash.shellAliases = {
    ns = "nixos-switch";
  };

  # Claude Code shortcuts, defined only when the `claude` binary is on PATH so
  # they vanish cleanly if it's ever not installed:
  #   c  -> claude
  #   cw -> claude in a fresh git worktree (accepts an optional worktree name)
  programs.bash.bashrcExtra = ''
    if command -v claude >/dev/null 2>&1; then
      alias c='claude'
      alias cw='claude --worktree'
    fi
  '';

  # claude-sync integration: keep sessions synced with the R2 remote.
  # The config.yaml + age-key.txt are delivered by agenix (see
  # modules/system/secrets.nix); this only decides WHEN to push/pull.
  programs.bash.initExtra = ''
    # TODO(human): decide the auto-sync trigger and fill this in.
  '';

  # Auto-enter a project's dev shell on cd (reads .envrc → `use flake`).
  # nix-direnv caches the shell so re-entry is instant.
  programs.direnv = {
    enable = true;
    nix-direnv.enable = true;
  };
}
