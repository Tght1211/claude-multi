# 🎯 claude-multi

> 一条命令切供应商 —— `claude-deepseek`、`claude-kimi`、`claude-openrouter` ... 每个终端窗口独立，互不干扰。

打开三个终端，同时跑三个不同的供应商，**不用改任何配置文件**：

```sh
# 终端 A                          # 终端 B                          # 终端 C
$ claude-deepseek                 $ claude-kimi                     $ claude-openrouter
> 帮我写个排序算法                  > 总结一下这篇文档                  > review this PR
```

每个 `claude-<名称>` 命令会自动把当前终端的环境变量切到对应供应商，然后启动 claude。退出 claude 后 env 还在，继续 `claude` 还是走同一个供应商。

跟 [cc-switch](https://github.com/farion1231/cc-switch) 的区别：cc-switch 改 `settings.json` 是**全局生效**的；claude-multi 改的是 **shell env**，**每个终端独立**。两者搭配使用效果最佳 👇

---

## 🚀 一键安装

```sh
curl -fsSL https://raw.githubusercontent.com/Tght1211/claude-multi/main/install.sh | bash
```

完成后开个新终端，或运行 `source ~/.zshrc`。

> 💡 重跑同一条 `curl | bash` 会自动 `git pull` 更新，不会重复改 `.zshrc`。

---

## ⚡ 快速开始（3 分钟上手）

### Step 1：处理 settings.json 冲突

> 🔔 **重要**：`~/.claude/settings.json` 的 `env` 块会**覆盖** shell env。claude-multi 每次启动前会自动检测并提示同步，但你也可以提前处理：

| 你的情况 | 怎么做 |
|---|---|
| 🔄 已有 cc-switch | 在 cc-switch 中选一个 `"env": {}` 的 profile |
| 📋 settings.json 里有 env 配置 | 运行 `ccm sync` 一键导入到 ccm 并自动清空 |
| ✨ 全新用户 | 什么都不用做，`~/.claude/settings.json` 默认没有 env 块 |

### Step 2：添加你的第一个供应商

**最快方式 — 从 cc-switch / settings.json 同步：**
```sh
ccm sync                # 🔍 自动检测 settings.json 的 env，导入为 ccm 供应商，然后清空 env
```

**从模板快速创建：**
```sh
cp ~/.claude-multi/providers/deepseek.env.example ~/.claude-multi/providers/deepseek.env
ccm edit deepseek       # 📝 替换 YOUR_DEEPSEEK_KEY_HERE 为真实 token
ccm reload              # 🔄 重新扫描
```

**用内置预设（如 Kimi 1M）：**
```sh
ccm preset kimi-1m kimi    # 📦 一键创建 kimi 供应商
ccm edit kimi              # 📝 替换 token
ccm reload
```

### Step 3：跑起来！🎉

```sh
claude-deepseek            # 🚀 这个终端走 DeepSeek
claude-kimi -p "hi"        # 🚀 一次性提问
claude-openrouter          # 🚀 这个终端走 OpenRouter
```

> 🛡️ 每次 `claude-<名称>` 启动前，会**自动检测** settings.json 是否有冲突。如果有，会提示你是否同步并清空 —— 确保 ccm 始终生效。

---

## 📖 核心用法

### `claude-<名称>` —— 切 env + 启动 claude（最推荐 ⭐）

配好供应商后，直接用 `claude-<名称>` 启动：

```sh
claude-deepseek                 # 切到 deepseek，启动 claude
claude-qwen -p "总结一下..."     # 切到 qwen，传参给 claude
claude                          # 退出后 env 还在，继续走刚才的供应商
claude-kimi                     # 同一个终端里切到 kimi
```

> 💡 `claude-<名称>` 会**自动检测** settings.json 冲突 → 提示同步 → 清空 → 启动。全程无需手动处理。

支持的供应商名称取决于你在 `~/.claude-multi/providers/` 下配了哪些 `.env` 文件。比如：

| .env 文件 | 启动命令 | 供应商 |
|---|---|---|
| `deepseek.env` | `claude-deepseek` | DeepSeek |
| `kimi.env` | `claude-kimi` | Kimi / 月之暗面 |
| `openrouter.env` | `claude-openrouter` | OpenRouter |
| `dashscope.env` | `claude-dashscope` | 阿里云 DashScope |
| `mimo.env` | `claude-mimo` | 小米 MIMO |
| `minimax.env` | `claude-minimax` | MiniMax |
| `mo.env` | `claude-mo` | 自定义 |
| `qwen.env` | `claude-qwen` | 通义千问 |

按 `claude-<TAB>` 可以看到所有可用的供应商名称。

### `ccm use <名称>` —— 只切 env，不启动 claude

```sh
ccm use deepseek                # 切换 env
echo $ANTHROPIC_BASE_URL        # 验证
claude                          # 走 deepseek
```

### `ccm sync` —— 一键同步 settings.json 🔧

```sh
ccm sync                        # 从 settings.json 导入 env → 创建供应商 → 清空 settings.json
ccm sync my-provider            # 指定供应商名称
```

> 🛡️ 这是解决 "settings.json 覆盖 shell env" 问题的终极方案。运行一次，永久解决冲突。

### 管理命令

```sh
ccm list                        # 📋 列出所有供应商，✓ 标记当前在用的
ccm which                       # 🔍 打印当前供应商名
ccm add <名称>                  # ➕ 交互式新建 .env
ccm import [名称] [来源]         # 📥 从 JSON / settings.json 导入
ccm preset [名称] [供应商]       # 📦 从内置预设创建
ccm sync [名称]                 # 🔄 同步 settings.json 并清空
ccm edit <名称>                 # ✏️  用 $EDITOR 编辑
ccm rm <名称>                   # 🗑️  删除
ccm reload                      # 🔃 重新扫描 .env 文件
ccm unuse                       # 🧹 清除当前终端 env
ccm doctor                      # 🏥 体检：检测冲突、路径、语法等
```

### Tab 补全（zsh）

```sh
claude-<TAB>                    # → claude-deepseek claude-kimi claude-openrouter ...
ccm use <TAB>                   # → deepseek kimi openrouter ...
ccm sync <TAB>                  # → (供应商名列表)
```

---

## 🛡️ 自动冲突检测（Guard）

**这是 claude-multi 的核心安全机制**：每次运行 `claude-<名称>` 或 `ccm use` 时，会自动检测 `~/.claude/settings.json` 的 `env` 块。

如果检测到冲突：
```
🔔 检测到 settings.json 中有环境变量配置
⚠️  这些值会覆盖 ccm 的 shell env，导致供应商切换失效。
💡 (建议搭配 cc-switch 使用，选一个 env: {} 的 profile)

🔄 是否同步到 ccm 并清空 settings.json env? [Y/n]
```

- 选 `Y`（默认）→ 自动运行 `ccm sync`，导入为供应商并清空 settings.json
- 选 `N` → 再问是否只清空不同步
- 都不选 → 阻止启动，直到手动解决

> 💨 设 `CCM_NO_GUARD=1` 可跳过检测（用于脚本/CI 等非交互场景）。

---

## 📥 新增供应商（5 种方式）

### 方式 1：`ccm sync` —— 从 settings.json 一键同步（最推荐 ⭐）

如果你已经在 settings.json / cc-switch 里配好了供应商：

```sh
ccm sync                # 自动读取 settings.json → 导入 → 清空 env
```

一步到位，导入和清空都搞定。

### 方式 2：`ccm preset` —— 内置快捷预设

```sh
ccm preset                       # 查看可用预设
ccm preset kimi-1m kimi          # 用预设创建 kimi 供应商
ccm edit kimi                    # 替换 token
ccm reload
claude-kimi                      # 🚀
```

| 预设名 | 说明 |
|---|---|
| `kimi-1m` | 🌙 Kimi K2.5 Turbo — 1M 上下文窗口 |
| `idealab` | 🏢 阿里 idealab — Claude Opus 4.7 代理 |

### 方式 3：`ccm add` —— 交互式 3 个问题

```sh
ccm add deepseek
# ANTHROPIC_BASE_URL  : https://api.deepseek.com/anthropic
# ANTHROPIC_AUTH_TOKEN: sk-xxx
# ANTHROPIC_MODEL     : deepseek-chat
ccm reload && claude-deepseek
```

### 方式 4：从模板复制

```sh
ls ~/.claude-multi/providers/*.env.example
# openrouter  deepseek  kimi  minimax  mimo  dashscope  anthropic-third-party

cp ~/.claude-multi/providers/kimi.env.example ~/.claude-multi/providers/kimi.env
ccm edit kimi              # 替换 token
ccm reload && claude-kimi
```

### 方式 5：手写 `.env`（最灵活）

```sh
cat > ~/.claude-multi/providers/mo.env <<'EOF'
export ANTHROPIC_AUTH_TOKEN="your-token"
export ANTHROPIC_BASE_URL="https://your-proxy.com/anthropic"
export ANTHROPIC_MODEL="your-model"
EOF
ccm reload && claude-mo
```

### 配完验证

```sh
ccm doctor                     # 🏥 检测 settings.json 冲突 + .env 语法
claude-<名称> -p "hi"          # 🧪 实际跑一下确认
```

---

## 📁 供应商配置文件格式

纯 shell 片段，会被直接 `source`。任意 `ANTHROPIC_*` / `CLAUDE_CODE_*` 变量都支持。

```sh
# ~/.claude-multi/providers/openrouter.env
export ANTHROPIC_AUTH_TOKEN="sk-or-v1-..."
export ANTHROPIC_BASE_URL="https://openrouter.ai/api/anthropic"
export ANTHROPIC_MODEL="anthropic/claude-sonnet-4.6"
export ANTHROPIC_DEFAULT_OPUS_MODEL="anthropic/claude-opus-4.7"
export ANTHROPIC_DEFAULT_SONNET_MODEL="anthropic/claude-sonnet-4.6"
export ANTHROPIC_DEFAULT_HAIKU_MODEL="anthropic/claude-haiku-4.5"
```

```sh
# ~/.claude-multi/providers/kimi.env
export ANTHROPIC_AUTH_TOKEN="sk-..."
export ANTHROPIC_BASE_URL="https://api.kimi.com/coding/anthropic"
export ANTHROPIC_MODEL="kimi-k2.5-turbo-preview"
export ANTHROPIC_SMALL_FAST_MODEL="kimi-k2.5-turbo-preview"
export ANTHROPIC_DEFAULT_SONNET_MODEL="kimi-k2.5-turbo-preview"
export ANTHROPIC_DEFAULT_OPUS_MODEL="kimi-k2.5-turbo-preview"
export ANTHROPIC_DEFAULT_HAIKU_MODEL="kimi-k2.5-turbo-preview"
```

> 🔒 `.env` 文件自动被 gitignore 保护，token 永远不会被误提交。

---

## 📂 文件结构

```
~/.claude-multi/
├── init.sh                         # 被 .zshrc source，定义 claude-* 函数 + guard + ccm wrapper
├── ccm                             # 独立 CLI（list/add/import/sync/preset/edit/rm/doctor）
├── install.sh                      # 幂等安装器
├── providers/
│   ├── .gitignore                  # 🔒 忽略 *.env，保留 *.example
│   ├── openrouter.env.example      # 📦 模板
│   ├── deepseek.env.example
│   ├── kimi.env.example
│   ├── minimax.env.example
│   ├── mimo.env.example
│   ├── dashscope.env.example
│   ├── anthropic-third-party.env.example
│   └── deepseek.env                # 🔑 你的真实配置（gitignored）
└── completions/_ccm                # zsh tab 补全
```

---

## ❓ 常见问题

**`claude-deepseek` 跑了，但 `claude` 还是走旧供应商？**

🔔 99% 是 `~/.claude/settings.json` 的 `env` 块非空。两个办法：
- 运行 `ccm sync` 一键同步并清空
- 或运行 `ccm doctor` 看具体冲突的 key

> 💡 正常情况下 `claude-<名称>` 会自动检测并提示你同步，不需要手动处理。

**加了新的 `.env` 文件，但 `claude-xxx` 不存在？**

🔃 跑 `ccm reload`，或开新终端。

**想让这个终端保持 deepseek，临时跑一次 kimi？**

开新终端。或用子 shell：
```sh
(ccm use kimi && claude -p "hi")    # env 局限在子 shell 里
```

**Token 会被误提交吗？**

🔒 不会。`providers/*.env` 在 `.gitignore` 里，只有 `*.env.example` 模板会被提交。

**怎么跳过每次启动前的冲突检测？**

```sh
CCM_NO_GUARD=1 claude-deepseek     # 单次跳过
# 或 export CCM_NO_GUARD=1        # 永久跳过（不推荐）
```

---

## 🤝 与 cc-switch 共存

| 工具 | 管什么 |
|---|---|
| **cc-switch** | `settings.json` —— hooks、statusLine、默认模型等 |
| **claude-multi** | Shell 环境变量（`ANTHROPIC_*`、`CLAUDE_CODE_*`） |

最佳实践：
1. cc-switch 选一个 `env: {}` 的 profile
2. 在 cc-switch 里配好供应商（env 写在 profile 里）
3. 运行 `ccm sync` 把 env 同步到 ccm 并清空 settings.json
4. 以后直接用 `claude-<名称>` 启动

---

## License

MIT
