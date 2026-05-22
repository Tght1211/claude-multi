# claude-multi

> 按终端窗口快速切换 Claude Code 的环境变量 —— 多个窗口同时跑不同的 Anthropic 资源供应商。

打开一个终端跑 **idealab**，另一个跑 **DashScope/Qwen**，第三个跑 **Anthropic 官方** —— 同时进行，期间不用动任何配置文件。

```sh
# 终端 A
$ claude-idealab         # 把这个终端的 env 切到 idealab，然后启动 claude
> hello
^D                        # 退出 claude
$ claude                  # env 还在，依然走 idealab
> ...

# 终端 B（同时）
$ claude-qwen            # 这个终端切到 qwen，不影响终端 A
> ...
```

跟 [cc-switch](https://github.com/farion1231/cc-switch) 的区别：cc-switch 改 `settings.json` 是**全局生效**的，所有窗口共用一份配置；claude-multi 改的是 **shell env**，**每个终端独立**。

---

## 🚀 一键安装

```sh
curl -fsSL https://raw.githubusercontent.com/Tght1211/claude-multi/main/install.sh | bash
```

完成后开个新终端，或运行 `source ~/.zshrc`，然后：

```sh
ccm doctor        # 体检（重要！见下文优先级一节）
ccm add idealab   # 交互式新建第一个供应商
claude-idealab    # 跑起来
```

> 重跑同一条 `curl | bash` 命令会自动 `git pull` 更新到最新版，不会重复改 `.zshrc`。

如果想手动安装：

```sh
git clone https://github.com/Tght1211/claude-multi.git ~/.claude-multi
bash ~/.claude-multi/install.sh
```

---

## 为什么需要这个

Claude Code 从两个地方读供应商配置：

1. `~/.claude/settings.json` 的 `env` 块 —— **全局**生效
2. Shell 环境变量 —— **每个终端独立**

`settings.json` 的优先级更高，所以单纯在不同 shell 里 `export` 不同的值是没用的。claude-multi 就是补这块缺失的工具。

跟 cc-switch 不冲突：cc-switch 管 `settings.json`（hooks、statusLine、默认 model 等），claude-multi 管 shell env。只要 cc-switch 选一个 `env: {}` 的 profile 就行，下面详述。

---

## ⚠️ 优先级（用之前必须看的一节）

这是使用 claude-multi（或任何想从 shell 控制 Claude Code env 的工具）**最重要的一个事实**。

Claude Code 启动时，同一个变量（比如 `ANTHROPIC_BASE_URL`）可能在多个地方被设置。优先级是：

| 优先级 | 来源 | 作用域 | 由谁设置 |
|---|---|---|---|
| 🟢 **赢** | `~/.claude/settings.json` 里 `"env": { ... }` | 全局 | cc-switch / 手动改 |
| 🔴 **输** | Shell 导出的环境变量（`export FOO=bar`） | 每个终端独立 | claude-multi / 你的 `.zshrc` |

> **具体说**：如果 `settings.json` 里有 `"env": { "ANTHROPIC_BASE_URL": "https://x.com" }`，
> 那么不管你在 shell 里 `export ANTHROPIC_BASE_URL=https://y.com` 还是跑 `ccm use foo`，
> Claude Code **实际还是会访问 `https://x.com`**。你设的 shell 值被静默覆盖了。

（已对照 [Claude Code 官方文档](https://docs.claude.com/en/docs/claude-code/settings) 确认。）

### 想让 claude-multi 真正生效，必须做这一步

| 你的情况 | 怎么做 |
|---|---|
| 用 cc-switch | 选一个 `"env": {}` 的 profile 并保持激活 |
| 不用 cc-switch | 手动把 `~/.claude/settings.json` 里的 `env` 字段改成 `{}` 或删掉 |

装完后，`ccm doctor` 会自动检测这个冲突，并明确告诉你哪些 key 在冲突：

```
⚠ /Users/you/.claude/settings.json has a non-empty 'env' block.
  conflicting keys: ANTHROPIC_AUTH_TOKEN, ANTHROPIC_BASE_URL, ANTHROPIC_MODEL, ...
  Those values will OVERRIDE anything ccm sets in the shell.
  Fix: in cc-switch, switch to a profile whose 'env' is {} (empty),
       or edit /Users/you/.claude/settings.json and replace the env block with: "env": {}
```

**没修这一步之前**：claude-multi 看起来在工作（命令都不报错），但**其实不切换供应商** —— `ccm use idealab` 显示切换成功，`claude` 还是会走 `settings.json` 里钉住的那个供应商。

---

## 使用

### 主用法 1：`claude-<name>` —— 切 env + 启动 claude（一行搞定）

```sh
claude-idealab               # 把这个终端的 env 切到 idealab，然后启动 claude
claude-qwen -p "总结一下..."   # 所有参数原样传给 claude
claude                        # 退出 claude 后，env 还在这个终端，继续走刚才那个供应商
claude-idealab                # 同一个终端里再切回来
```

跑过 `claude-<name>` 之后，env 会**留在这个终端里**，直到关掉窗口或 `ccm unuse`。

### 主用法 2：`ccm use <name>` —— 只切 env，不启动 claude

```sh
ccm use idealab
echo $ANTHROPIC_BASE_URL      # idealab 的 URL
claude                         # 走 idealab
cc                             # 你自己的 alias 也走 idealab
```

### 管理供应商

```sh
ccm list                       # 列出所有供应商，✓ 标记当前窗口在用的
ccm which                      # 打印当前窗口的供应商名
ccm add <name>                 # 交互式新建一个 .env
ccm edit <name>                # 用 $EDITOR 打开一个 .env
ccm rm <name>                  # 删除一个 .env
ccm reload                     # 手动加了 .env 文件后，重新扫描
ccm unuse                      # 清掉当前 shell 的 env（回到 settings.json 默认）
ccm doctor                     # 体检：检测 settings.json 冲突、.env 是否能解析等
```

### Tab 补全（zsh）

```sh
claude-<TAB>                   # zsh 自动补全所有 claude-* 函数
ccm use <TAB>                  # → idealab qwen ...
ccm edit <TAB>
```

---

## 新增供应商（3 种方式，从快到灵活）

### 方式 1：`ccm add <name>` —— 交互式问 3 个值（最快）

```sh
ccm add deepseek
# 依次输入：
#   ANTHROPIC_BASE_URL  : https://api.deepseek.com/anthropic
#   ANTHROPIC_AUTH_TOKEN: sk-xxx
#   ANTHROPIC_MODEL     : deepseek-chat
# 自动写到 ~/.claude-multi/providers/deepseek.env
# 上面输入的 model 会同时填到 OPUS/SONNET/HAIKU 三个变量
ccm reload                   # 或开新终端
claude-deepseek              # 就能用了
```

### 方式 2：从模板复制（字段较多的供应商更省事）

仓库里已有两个开箱即用的模板，token 是占位符：

```sh
ls ~/.claude-multi/providers/
# idealab.env.example  qwen.env.example

cp ~/.claude-multi/providers/qwen.env.example ~/.claude-multi/providers/qwen.env
ccm edit qwen                # 用 $EDITOR 打开，把 sk-YOUR_DASHSCOPE_KEY_HERE 换成真 token
ccm reload
claude-qwen
```

qwen 模板把 DashScope 的全部字段（包括 `*_MODEL_NAME` 和 `CLAUDE_CODE_SUBAGENT_MODEL`）都填好了，**只需替换 token**。

### 方式 3：直接手写 `.env`（最灵活，任意变量都行）

```sh
cat > ~/.claude-multi/providers/kimi.env <<'EOF'
export ANTHROPIC_AUTH_TOKEN="sk-xxx"
export ANTHROPIC_BASE_URL="https://api.moonshot.cn/anthropic"
export ANTHROPIC_MODEL="kimi-k2-turbo-preview"
EOF
ccm reload
claude-kimi
```

### 配完一定要跑这两步

```sh
ccm doctor                   # 体检：检测 settings.json 是否会覆盖你刚配的 env（最常见的坑）
claude-<name> -p "hi"        # 实际跑一下，确认走的是新供应商
```

> 你的 `.env` 文件自动被 gitignore 保护，token 永远不会被误提交。

---

## 供应商配置文件格式

纯 shell 片段，会被直接 source。任意 `ANTHROPIC_*` / `CLAUDE_CODE_*` 变量都支持，没有固定 schema。

```sh
# ~/.claude-multi/providers/idealab.env
export ANTHROPIC_AUTH_TOKEN="..."
export ANTHROPIC_BASE_URL="https://idealab.alibaba-inc.com/api/anthropic"
export ANTHROPIC_MODEL="claude-opus-4-7"
export ANTHROPIC_DEFAULT_OPUS_MODEL="claude-opus-4-7"
export ANTHROPIC_DEFAULT_SONNET_MODEL="claude-opus-4-7"
export ANTHROPIC_DEFAULT_HAIKU_MODEL="claude-opus-4-7"
```

```sh
# ~/.claude-multi/providers/qwen.env（DashScope，Anthropic 兼容端点）
export ANTHROPIC_AUTH_TOKEN="sk-..."
export ANTHROPIC_BASE_URL="https://dashscope.aliyuncs.com/apps/anthropic"
export ANTHROPIC_MODEL="qwen-latest-series-invite-beta-v34"
export ANTHROPIC_DEFAULT_OPUS_MODEL="qwen-latest-series-invite-beta-v34[1M]"
export ANTHROPIC_DEFAULT_HAIKU_MODEL="qwen-latest-series-invite-beta-v34"
export ANTHROPIC_DEFAULT_SONNET_MODEL="qwen-latest-series-invite-beta-v34"
export CLAUDE_CODE_SUBAGENT_MODEL="qwen-latest-series-invite-beta-v23"
```

供应商 `.env` 文件**默认被 gitignore**，token 永远不会被误提交。仓库里只放 `*.env.example` 模板。

---

## 文件结构

```
~/.claude-multi/
├── init.sh                     # 被 .zshrc source，定义 claude-* 函数和 ccm wrapper
├── ccm                         # 独立 CLI（list / add / edit / rm / doctor 等）
├── install.sh                  # 幂等安装器（同一份脚本支持远程/本地两种模式）
├── providers/
│   ├── .gitignore              # 忽略所有 *.env（保护 token），保留 *.example
│   ├── idealab.env.example     # 模板
│   ├── qwen.env.example
│   └── idealab.env             # 你的真实配置（gitignored，不会被提交）
└── completions/_ccm            # zsh tab 补全
```

---

## 常见问题

**`claude-idealab` 跑了，但 `claude` 还是走旧供应商**

99% 是 `~/.claude/settings.json` 的 `env` 块非空把 shell env 盖掉了。跑 `ccm doctor`，输出里会列出具体冲突的 key 和修复方法。

**加了新的 `.env` 文件，但 `claude-newname` 不存在**

跑 `ccm reload`，或开新终端。`claude-<name>` 函数是 `init.sh` 被 source 时生成的。

**想让这个终端保持 idealab，临时跑一次 qwen 不要污染**

开新终端（每个终端自己的 env）。或者用显式子 shell：

```sh
(ccm use qwen && claude -p "hi")   # 圆括号把 env 局限在这个子 shell，外面的 idealab 不动
```

**Token 不小心被提交了？**

不用担心，`providers/*.env` 一开始就在 `.gitignore` 里，git 永远不会跟踪它们。只有 `*.env.example` 模板会被提交。

**重装/更新**

直接再跑一次安装命令即可：

```sh
curl -fsSL https://raw.githubusercontent.com/Tght1211/claude-multi/main/install.sh | bash
```

它会自动 `git pull` 更新，不会重复改 `.zshrc`，你的 provider .env 文件因为是 gitignored 所以也不会被动。

**卸载**

```sh
# 1. 从 .zshrc 删掉 # >>> claude-multi >>> 那一段（5 行）
# 2. 删除安装目录
rm -rf ~/.claude-multi
# 3. 开新终端
```

---

## 与 cc-switch 共存

| 工具 | 管什么 |
|---|---|
| **cc-switch** | `~/.claude/settings.json` —— hooks、statusLine、默认模型等 |
| **claude-multi** | Shell 环境变量（`ANTHROPIC_*`、`CLAUDE_CODE_*`） |

cc-switch 选一个 `env: {}` 的 profile，然后让 claude-multi 在每个终端按需切供应商即可。

---

## License

MIT
