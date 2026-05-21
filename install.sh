#!/usr/bin/env bash
# install.sh — idempotent installer for claude-multi.
# Safe to re-run. Adds 3 lines (marked with a sentinel) to your shell rc.
set -euo pipefail

CCM_HOME="${CCM_HOME:-$HOME/.claude-multi}"
SENTINEL='# >>> claude-multi >>>'
SENTINEL_END='# <<< claude-multi <<<'

# Detect target rc file
if [ -n "${ZSH_VERSION:-}" ] || [ "${SHELL##*/}" = "zsh" ]; then
  RC="$HOME/.zshrc"
else
  RC="$HOME/.bashrc"
fi

# Make scripts executable
chmod +x "$CCM_HOME/ccm" "$CCM_HOME/install.sh" 2>/dev/null || true

# Already installed?
if grep -qF "$SENTINEL" "$RC" 2>/dev/null; then
  echo "install: already present in $RC (sentinel found) — skipping append"
else
  cat >> "$RC" <<EOF

$SENTINEL
# Loads claude-multi: defines claude-<name> functions + ccm shell helper.
[ -f "\$HOME/.claude-multi/init.sh" ] && . "\$HOME/.claude-multi/init.sh"
# zsh completion for ccm (only effective in zsh; harmless in bash)
[ -n "\${ZSH_VERSION:-}" ] && fpath=("\$HOME/.claude-multi/completions" \$fpath)
$SENTINEL_END
EOF
  echo "install: appended source block to $RC"
fi

cat <<'EOF'

Next steps:
  1. Open a new terminal (or `source ~/.zshrc`).
  2. Run `ccm doctor` to check for settings.json env-block conflicts.
     If it warns, switch cc-switch to a profile whose `env` is {} (empty),
     or manually edit ~/.claude/settings.json to set "env": {}.
  3. `ccm list` to see your providers.
  4. `ccm use idealab`  (or `claude-idealab -p "hi"` for one-shot).
EOF
