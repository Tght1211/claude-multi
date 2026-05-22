#!/usr/bin/env bash
# install.sh — claude-multi 一键安装器
#
# 两种用法都支持（同一个脚本，自动判断）：
#   1) 远程一键安装：
#      curl -fsSL https://raw.githubusercontent.com/Tght1211/claude-multi/main/install.sh | bash
#   2) 已 clone 到 ~/.claude-multi 后手动跑：
#      bash ~/.claude-multi/install.sh
#
# 关键行为：
#   - 检查 $CCM_HOME 里是否已经有 init.sh 和 ccm
#       有 → 跳过 clone；如果是 git 仓库则尝试 pull 更新
#       没有 → git clone 仓库到 $CCM_HOME
#   - 给可执行文件加 +x
#   - 幂等向 ~/.zshrc (或 ~/.bashrc) 追加 source 行（带哨兵注释，重跑不会重复加）
#
# 环境变量覆盖：
#   CCM_HOME   安装路径，默认 ~/.claude-multi
#   CCM_REPO   仓库地址，默认 https://github.com/Tght1211/claude-multi.git
#   CCM_BRANCH 分支，默认 main
set -euo pipefail

CCM_HOME="${CCM_HOME:-$HOME/.claude-multi}"
CCM_REPO="${CCM_REPO:-https://github.com/Tght1211/claude-multi.git}"
CCM_BRANCH="${CCM_BRANCH:-main}"
SENTINEL='# >>> claude-multi >>>'
SENTINEL_END='# <<< claude-multi <<<'

say() { printf '\033[1;36m==>\033[0m %s\n' "$*"; }
ok()  { printf '\033[1;32m✓\033[0m %s\n'    "$*"; }
warn(){ printf '\033[1;33m⚠\033[0m %s\n'    "$*"; }
die() { printf '\033[1;31m✗\033[0m %s\n' "$*" >&2; exit 1; }

# ---------- Step 1: 确保 $CCM_HOME 是 populated 的 claude-multi 安装 ---------

if [ -f "$CCM_HOME/init.sh" ] && [ -f "$CCM_HOME/ccm" ]; then
  # 已经装好，看看能不能 pull 更新
  if [ -d "$CCM_HOME/.git" ]; then
    say "$CCM_HOME 已是 git 仓库，尝试更新..."
    if git -C "$CCM_HOME" pull --ff-only --quiet 2>/dev/null; then
      ok "已更新到 origin/$CCM_BRANCH 的最新提交"
    else
      warn "git pull 跳过（可能本地有改动或非默认分支），继续用现有版本"
    fi
  else
    ok "$CCM_HOME 已存在（非 git 仓库），跳过 clone"
  fi
else
  command -v git >/dev/null 2>&1 || die "需要先装 git（macOS 上跑 xcode-select --install）"
  if [ -e "$CCM_HOME" ] && [ -n "$(ls -A "$CCM_HOME" 2>/dev/null || true)" ]; then
    die "$CCM_HOME 已存在但不完整（缺 init.sh 或 ccm）。请先备份或移除它，然后重新跑这个命令。"
  fi
  say "Clone $CCM_REPO → $CCM_HOME"
  mkdir -p "$(dirname "$CCM_HOME")"   # 确保父目录存在
  git clone --depth=1 --branch "$CCM_BRANCH" --quiet "$CCM_REPO" "$CCM_HOME"
  ok "已克隆到 $CCM_HOME"
fi

# 兜底验证：clone 之后所有期望的文件都应该存在
for f in init.sh ccm completions/_ccm; do
  [ -e "$CCM_HOME/$f" ] || die "$CCM_HOME/$f 不存在，安装中止"
done

# ---------- Step 2: 给可执行文件加 +x ----------------------------------------

chmod +x "$CCM_HOME/ccm" "$CCM_HOME/install.sh" 2>/dev/null || true
ok "已设置 ccm 和 install.sh 为可执行"

# ---------- Step 3: 幂等追加到 shell rc --------------------------------------

case "${SHELL##*/}" in
  zsh)  rc="$HOME/.zshrc" ;;
  bash) rc="$HOME/.bashrc" ;;
  *)
    if [ -n "${ZSH_VERSION:-}" ]; then rc="$HOME/.zshrc"
    else rc="$HOME/.bashrc"
    fi
    ;;
esac

if [ -f "$rc" ] && grep -qF "$SENTINEL" "$rc" 2>/dev/null; then
  ok "$rc 已包含 claude-multi 配置块（跳过追加）"
else
  cat >> "$rc" <<EOF

$SENTINEL
# claude-multi: 按终端窗口切 Claude Code 供应商 env
[ -f "\$HOME/.claude-multi/init.sh" ] && . "\$HOME/.claude-multi/init.sh"
# zsh 的 tab 补全（在 bash 下无害）
[ -n "\${ZSH_VERSION:-}" ] && fpath=("\$HOME/.claude-multi/completions" \$fpath)
$SENTINEL_END
EOF
  ok "已追加 source 行到 $rc"
fi

# ---------- Step 4: 完成 -----------------------------------------------------

cat <<EOF

🎉 claude-multi 安装完成！

下一步：
  1. 开个新终端，或运行：  $(printf '\033[1msource %s\033[0m' "$rc")
  2. 体检：               $(printf '\033[1mccm doctor\033[0m')
     （它会检测 ~/.claude/settings.json 的 env 块是否会覆盖 shell env）
  3. 新建第一个供应商：    $(printf '\033[1mccm add deepseek\033[0m')
  4. 使用：               $(printf '\033[1mclaude-deepseek\033[0m')  或  $(printf '\033[1mccm use deepseek && claude\033[0m')

文档：https://github.com/Tght1211/claude-multi
EOF
