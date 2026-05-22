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
      # 先清除可能的代理变量（从 official 切到其他 provider 时）
      unset HTTP_PROXY HTTPS_PROXY SOCKS5_PROXY ALL_PROXY \
            http_proxy https_proxy socks5_proxy all_proxy NO_PROXY no_proxy 2>/dev/null
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
            HTTP_PROXY HTTPS_PROXY SOCKS5_PROXY ALL_PROXY \
            http_proxy https_proxy socks5_proxy all_proxy NO_PROXY no_proxy \
            CCM_ACTIVE_PROVIDER
      echo "🧹 ccm: 已清除当前终端 env (claude 将使用 ~/.claude/settings.json 默认值)"
      ;;
    reload)
      _ccm_define_aliases
      echo "🔄 ccm: 已重新生成 claude-<名称> 函数 ($CCM_PROVIDERS_DIR)"
      ;;
    proxy)
      local subcmd="${1:-}"
      local state_file="$CCM_HOME/.proxy_on"
      local check_file="$CCM_HOME/.no_proxy_check"
      case "$subcmd" in
        on)
          mkdir -p "$CCM_HOME"
          touch "$state_file"
          echo "🛡️  ccm: 官方代理保护已开启 (直连 claude 将自动注入代理)"
          ;;
        off)
          rm -f "$state_file"
          echo "🔓 ccm: 官方代理保护已关闭 (直连 claude 不走代理)"
          ;;
        toggle)
          if [ -f "$state_file" ]; then
            rm -f "$state_file"
            echo "🔓 ccm: 官方代理保护已关闭"
          else
            mkdir -p "$CCM_HOME"
            touch "$state_file"
            echo "🛡️  ccm: 官方代理保护已开启"
          fi
          ;;
        set)
          local proxy_url="${2:-}"
          if [ -z "$proxy_url" ]; then
            printf '代理地址: ' >&2
            read -r proxy_url
          fi
          [ -z "$proxy_url" ] && { echo "ccm: 代理地址不能为空" >&2; return 1; }
          local socks_url
          case "$proxy_url" in
            http://*) socks_url="socks5://${proxy_url#http://}" ;;
            *)        socks_url="$proxy_url" ;;
          esac
          local official_env="$CCM_PROVIDERS_DIR/official.env"
          mkdir -p "$CCM_PROVIDERS_DIR"
          {
            echo "# Provider: official (代理配置, $(date +%Y-%m-%d))"
            echo "export HTTP_PROXY=\"$proxy_url\""
            echo "export HTTPS_PROXY=\"$proxy_url\""
            echo "export SOCKS5_PROXY=\"$socks_url\""
          } > "$official_env"
          echo "📝 $official_env"
          echo "🛡️  代理已设置: $proxy_url"
          # 自动开启代理保护
          touch "$state_file"
          echo "🛡️  官方代理保护已自动开启"
          ;;
        check)
          local check_action="${2:-}"
          case "$check_action" in
            on)
              rm -f "$check_file"
              echo "✅ 代理端口检测已开启"
              ;;
            off)
              mkdir -p "$CCM_HOME"
              touch "$check_file"
              echo "⏭️  代理端口检测已关闭"
              ;;
            status|"")
              if [ -f "$check_file" ]; then
                echo "⏭️  代理端口检测: 已关闭"
              else
                echo "✅ 代理端口检测: 已开启"
              fi
              ;;
            *)
              echo "用法: ccm proxy check on|off|status" >&2
              return 2
              ;;
          esac
          ;;
        status|"")
          if [ -f "$state_file" ]; then
            echo "🛡️  官方代理保护: 已开启"
          else
            echo "🔓 官方代理保护: 未开启 (ccm proxy on 开启)"
          fi
          if [ -f "$check_file" ]; then
            echo "⏭️  代理端口检测: 已关闭"
          else
            echo "✅ 代理端口检测: 已开启"
          fi
          ;;
        *)
          echo "用法: ccm proxy on|off|toggle|set <URL>|check on|off|status" >&2
          return 2
          ;;
      esac
      ;;
    *)
      # Delegate to the standalone script
      command ccm "$cmd" "$@"
      ;;
  esac
}

# ---- proxy check: 检测代理端口是否可用 --------------------------------

_ccm_check_proxy() {
  local proxy_url="${1:-}"
  [ -z "$proxy_url" ] && return 1

  local host port
  # 从 URL 中提取 host:port  (支持 http://host:port, socks5://host:port 等)
  local addr="${proxy_url#*://}"
  host="${addr%%[:/]*}"
  port="${addr##*:}"
  port="${port%%/*}"

  [ -z "$host" ] || [ -z "$port" ] && return 1

  # 尝试连接，2 秒超时
  if command -v nc >/dev/null 2>&1; then
    nc -z -w 2 "$host" "$port" >/dev/null 2>&1
  elif [ -n "$BASH_VERSION" ]; then
    (echo >/dev/tcp/"$host"/"$port") 2>/dev/null
  else
    # zsh: 用 zmodload zsh/net/tcp
    zmodload zsh/net/tcp 2>/dev/null && ztcp -t 2 "$host" "$port" 2>/dev/null && { ztcp -c; return 0; }
    # 最终回退: 不检测
    return 0
  fi
}

# ---- claude wrapper: 直连官方时自动注入代理 -------------------------
# 始终定义。运行时检查 $CCM_HOME/.proxy_on 状态文件决定是否注入代理。
# 用 ccm proxy on/off 控制开关。
# 仅在无 CCM_ACTIVE_PROVIDER 时生效，从 official.env 读取代理配置。
# 使用子 shell 隔离代理变量，不影响当前 shell 环境。
# 有 provider 激活时直接透传，代理不参与。
claude() {
  # 未开启代理保护 或 已有 provider 激活 → 直接透传
  if [ ! -f "$CCM_HOME/.proxy_on" ] || [ -n "${CCM_ACTIVE_PROVIDER:-}" ]; then
    command claude "$@"
    return $?
  fi

  local _ccm_official_env="$CCM_PROVIDERS_DIR/official.env"
  if [ -f "$_ccm_official_env" ]; then
    # 检测代理端口是否可用 (CCM_NO_PROXY_CHECK=1 或 ccm proxy check off 跳过)
    if [ -z "${CCM_NO_PROXY_CHECK:-}" ] && [ ! -f "$CCM_HOME/.no_proxy_check" ]; then
      local _proxy_url
      _proxy_url="$(. "$_ccm_official_env" 2>/dev/null; echo "${HTTPS_PROXY:-$HTTP_PROXY}")"
      if [ -n "$_proxy_url" ] && ! _ccm_check_proxy "$_proxy_url"; then
        echo "⚠️  代理 $_proxy_url 似乎未启动，直连官方可能有风险" >&2
        echo "   请先启动代理，或用 ccm use <供应商> 切换到第三方供应商" >&2
        echo "   ccm proxy check off 可跳过此检测" >&2
        echo
        if [ -t 0 ]; then
          printf '   是否仍然继续? [y/N] '
          local ans; read -r ans
          case "$ans" in
            y|Y|yes|YES) ;;
            *) echo "   已取消"; return 1 ;;
          esac
        fi
      fi
    fi
    (
      set -a
      . "$_ccm_official_env"
      set +a
      command claude "$@"
    )
  else
    echo "💡 未找到 official.env (直连官方无代理保护)" >&2
    echo "   运行 ccm proxy set <URL> 设置代理" >&2
    command claude "$@"
  fi
}
