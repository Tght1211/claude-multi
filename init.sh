# claude-multi — terminal-window-level Claude Code provider switching
# Sourced from ~/.zshrc (or ~/.bashrc). Generates one shell function per
# providers/*.env file and provides a `ccm` shell function for live switching.
#
# See README.md for usage. Prereq: ~/.claude/settings.json must NOT have a
# non-empty `env` block (Claude Code's settings env wins over shell env).
# The _ccm_guard function auto-detects this and offers to sync before launch.

export CCM_HOME="${CCM_HOME:-$HOME/.claude-multi}"
export CCM_PROVIDERS_DIR="$CCM_HOME/providers"
export CCM_SETTINGS_JSON="${CCM_SETTINGS_JSON:-$HOME/.claude/settings.json}"

# Put the ccm CLI on PATH (idempotent)
case ":$PATH:" in
  *":$CCM_HOME:"*) ;;
  *) export PATH="$CCM_HOME:$PATH" ;;
esac

# ---- guard: 启动前自动检测 settings.json 冲突 --------------------------------

# 每次 claude-<name> / ccm use 启动前自动调用。
# 如果 settings.json 有非空 env 块，提示用户同步到 ccm 并清空。
# 只有检测通过（env 为空或不存在）才允许启动 claude。
# 设置 CCM_NO_GUARD=1 可跳过检测。
_ccm_guard() {
  # 跳过检测的逃生口
  [ -n "${CCM_NO_GUARD:-}" ] && return 0

  # 文件不存在 → 无冲突
  [ -f "$CCM_SETTINGS_JSON" ] && [ -s "$CCM_SETTINGS_JSON" ] || return 0

  # 快速检测: settings.json 里是否有非空 env 块 (grep 级别，极快)
  grep -qE '"env"[[:space:]]*:[[:space:]]*\{' "$CCM_SETTINGS_JSON" 2>/dev/null && \
    grep -qE '"(ANTHROPIC|CLAUDE_CODE)_' "$CCM_SETTINGS_JSON" 2>/dev/null || return 0

  # 确认有冲突 — 非交互模式只警告
  if [ ! -t 0 ]; then
    echo "⚠️  settings.json env 非空，可能覆盖 ccm。运行 ccm sync 导入。" >&2
    return 0
  fi

  echo
  echo "  ⚠️  settings.json 中有 env 配置，会覆盖 ccm"
  echo "    1) 同步到 ccm"
  echo "    2) 同步并清空 settings.json env"
  echo "    3) 跳过"
  printf '    选择 [1/2/3]: '
  local ans
  read -r ans
  case "$ans" in
    1)
      command ccm sync "$@"
      ;;
    2)
      command ccm sync --clear "$@"
      ;;
    *)
      echo "  💡 稍后可运行 ccm sync 手动同步"
      ;;
  esac
}

# ---- generate claude-<name> functions ---------------------------------------

# Generate `claude-<name>` functions.
# Each function (a) runs _ccm_guard to check settings.json conflict,
# (b) injects the provider's env into the CURRENT shell — so subsequent
# plain `claude` commands in the same terminal keep using that provider —
# then (c) launches `claude`. No subshell, no exec: env persists after
# claude exits.
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
      _ccm_guard || return 1
      set -a
      . '${f}'
      set +a
      export CCM_ACTIVE_PROVIDER='${name}'
      claude \"\$@\"
    }"
  done
}
_ccm_define_aliases

# ---- ccm shell function -----------------------------------------------------

# `ccm` shell function: handles commands that must run in the current shell
# (use / unuse / reload) and delegates everything else to the standalone
# `ccm` script (list/which/add/edit/rm/doctor/help/sync/import/preset).
ccm() {
  local cmd="${1:-help}"
  shift 2>/dev/null
  case "$cmd" in
    use)
      local name="$1"
      if [ -z "$name" ]; then
        echo "ccm use: 缺少供应商名称" >&2
        echo "用法: ccm use <供应商名>" >&2
        return 2
      fi
      local envfile="$CCM_PROVIDERS_DIR/$name.env"
      if [ ! -f "$envfile" ]; then
        echo "ccm: 供应商 '$name' 不存在 ($envfile)" >&2
        echo "可用: $(ls "$CCM_PROVIDERS_DIR" 2>/dev/null | sed 's/\.env$//' | tr '\n' ' ')" >&2
        return 1
      fi
      _ccm_guard || return 1
      set -a
      . "$envfile"
      set +a
      export CCM_ACTIVE_PROVIDER="$name"
      echo "🚀 ccm: 当前终端已切换到 '$name' (base_url=$ANTHROPIC_BASE_URL)"
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
      echo "🧹 ccm: 已清除当前终端 env (claude 将使用 ~/.claude/settings.json 默认值)"
      ;;
    reload)
      _ccm_define_aliases
      echo "🔄 ccm: 已重新生成 claude-<名称> 函数 ($CCM_PROVIDERS_DIR)"
      ;;
    *)
      # Delegate to the standalone script
      command ccm "$cmd" "$@"
      ;;
  esac
}
