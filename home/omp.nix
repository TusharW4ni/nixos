# omp (oh-my-pi) coding agent. Coexists with pi-coding-agent (see
# home/tushar.nix); pi stays because treechat.nvim drives it over RPC.
{ pkgs, lib, ... }:
let
  settings = {
    # Roles route work by intent: the premium model only sees planning and
    # hard reasoning, while subagent fan-out (smol) runs cheap. Values are
    # provider-qualified — a bare "meta/muse-spark-1.3" is parsed as provider
    # "meta" and silently falls back to an unrelated default model.
    modelRoles = {
#      default = "openrouter/meta/muse-spark-1.3";
#      slow = "openrouter/meta/muse-wonder";
#      smol = "openrouter/z-ai/glm-5.3";
    };
  };
  configFile = (pkgs.formats.yaml { }).generate "omp-config.yml" settings;
in
{
  home.packages = [ pkgs.omp ];

  # Copied in as a writable file rather than a home.file store symlink: omp
  # locks and rewrites config.yml at runtime, and a read-only /nix/store
  # symlink fails both with EACCES. Runtime edits are overwritten on the next
  # switch — change settings here, not via `omp config set` or /settings.
  home.activation.ompConfig = lib.hm.dag.entryAfter [ "writeBoundary" ] ''
    run mkdir -p "$HOME/.omp/agent"
    run install -m 600 ${configFile} "$HOME/.omp/agent/config.yml"
  '';
}
