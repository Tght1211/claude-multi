# claude-multi — terminal-window-level Claude Code provider switching
# Sourced from ~/.zshrc (or ~/.bashrc). Generates one shell function per
# providers/*.env file and provides a `ccm` shell function for live switching.
#
# See README.md for usage. Prereq: ~/.claude/settings.json must NOT have a
# non-empty `env` block (Claude Code's settings env wins over shell env).
# Run `ccm doctor` to check.

export CCM_HOME="${CCM_HOME:-$HOME/.claude-multi}"
export CCM_PROVIDERS_DIR="$CCM_HOME/providers"

# Put the ccm CLI on PATH (idempotent)
case ":$PATH:" in
  *":$CCM_HOME:"*) ;;
  *) export PATH="$CCM_HOME:$PATH" ;;
esac

# Generate `claude-<name>` functions.
# Each function (a) injects the provider's env into the CURRENT shell — so
# subsequent plain `claude` commands in the same terminal keep using that
# provider — then (b) launches `claude`. No subshell, no exec: env persists
# after claude exits.
_ccm_define_aliases() {
  local f name
  # zsh: don't error if no .env files yet
  if [ -n "$ZSH_VERSION" ]; then
    setopt local_options null_glob
  fi
  for f in "$CCM_PROVIDERS_DIR"/*.env; do
    [ -e "$f" ] || continue
    name="$(basename "$f" .env)"
    # Guard: name must be a valid shell function identifier
    case "$name" in
      *[!a-zA-Z0-9_-]*) continue ;;
    esac
    eval "claude-${name}() {
      set -a
      . '${f}'
      set +a
      export CCM_ACTIVE_PROVIDER='${name}'
      claude \"\$@\"
    }"
  done
}
_ccm_define_aliases

# `ccm` shell function: handles commands that must run in the current shell
# (use / unuse / reload) and delegates everything else to the standalone
# `ccm` script (list/which/add/edit/rm/doctor/help).
ccm() {
  local cmd="${1:-help}"
  shift 2>/dev/null
  case "$cmd" in
    use)
      local name="$1"
      if [ -z "$name" ]; then
        echo "ccm use: missing provider name" >&2
        echo "usage: ccm use <provider>" >&2
        return 2
      fi
      local envfile="$CCM_PROVIDERS_DIR/$name.env"
      if [ ! -f "$envfile" ]; then
        echo "ccm: provider '$name' not found at $envfile" >&2
        echo "available: $(ls "$CCM_PROVIDERS_DIR" 2>/dev/null | sed 's/\.env$//' | tr '\n' ' ')" >&2
        return 1
      fi
      set -a
      . "$envfile"
      set +a
      export CCM_ACTIVE_PROVIDER="$name"
      echo "ccm: switched this shell to '$name' (base_url=$ANTHROPIC_BASE_URL)"
      ;;
    unuse)
      unset ANTHROPIC_AUTH_TOKEN ANTHROPIC_API_KEY ANTHROPIC_BASE_URL \
            ANTHROPIC_MODEL \
            ANTHROPIC_DEFAULT_HAIKU_MODEL ANTHROPIC_DEFAULT_OPUS_MODEL ANTHROPIC_DEFAULT_SONNET_MODEL \
            ANTHROPIC_DEFAULT_HAIKU_MODEL_NAME ANTHROPIC_DEFAULT_OPUS_MODEL_NAME ANTHROPIC_DEFAULT_SONNET_MODEL_NAME \
            ANTHROPIC_DEFAULT_HAIKU_MODEL_DESCRIPTION ANTHROPIC_DEFAULT_OPUS_MODEL_DESCRIPTION ANTHROPIC_DEFAULT_SONNET_MODEL_DESCRIPTION \
            ANTHROPIC_CUSTOM_HEADERS ANTHROPIC_BETAS \
            CLAUDE_CODE_SUBAGENT_MODEL \
            CCM_ACTIVE_PROVIDER
      echo "ccm: cleared shell env (claude will now use ~/.claude/settings.json defaults)"
      ;;
    reload)
      _ccm_define_aliases
      echo "ccm: regenerated claude-<name> functions from $CCM_PROVIDERS_DIR"
      ;;
    *)
      # Delegate to the standalone script
      command ccm "$cmd" "$@"
      ;;
  esac
}
