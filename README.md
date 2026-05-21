# claude-multi

> Per-terminal-window provider switching for [Claude Code](https://claude.com/claude-code).

Open one terminal running **idealab**, another running **DashScope/Qwen**, a third running **Anthropic official** — at the same time, no settings file editing in between.

```sh
# Terminal A
$ claude-idealab        # injects idealab env into THIS terminal, then launches claude
> hello
^D                       # exit claude
$ claude                 # still idealab, env persists
> ...

# Terminal B (simultaneously)
$ claude-qwen           # this terminal is on qwen, doesn't touch Terminal A
> ...
```

---

## Why this exists

Claude Code reads provider config (`ANTHROPIC_BASE_URL`, `ANTHROPIC_AUTH_TOKEN`, model IDs, …) from two places:

1. `~/.claude/settings.json` `env` block — **global** to all terminals.
2. Shell environment variables — **per-terminal**.

The settings.json `env` block wins, so just exporting different env vars in different shells doesn't work out of the box. `claude-multi` is the missing piece that makes the "shell env per terminal" model actually function.

It's also designed to coexist with [cc-switch](https://github.com/farion1231/cc-switch): cc-switch manages `settings.json` (hooks, statusLine, model defaults); claude-multi manages shell env. Just keep cc-switch on a profile whose `env` block is empty.

---

## ⚠️ Precedence: settings.json wins over shell env

This is the **single most important thing to understand** before using claude-multi (or any other tool that tries to set Claude Code env vars from the shell).

When Claude Code starts, it loads the same variable (e.g. `ANTHROPIC_BASE_URL`) from multiple sources. The precedence is:

| Priority    | Source                                        | Scope         | Set by                       |
|-------------|-----------------------------------------------|---------------|------------------------------|
| 🟢 **WINS** | `~/.claude/settings.json` → `"env": { ... }`  | global        | cc-switch / manual edit      |
| 🔴 **LOSES**| Shell-exported env vars (`export FOO=bar`)    | per-terminal  | claude-multi / your `.zshrc` |

> **Concretely**: if `settings.json` has `"env": { "ANTHROPIC_BASE_URL": "https://x.com" }`,
> then `ANTHROPIC_BASE_URL=https://y.com claude` (or `ccm use foo` → `claude`)
> **silently runs against `https://x.com`**. Your shell value is overridden.

Verified against [the official Claude Code env-vars docs](https://docs.claude.com/en/docs/claude-code/settings): the `env` field in `settings.json` is read at startup and injected into the process environment, overriding what the shell exported.

### What this means for claude-multi

claude-multi works **only when `settings.json` `env` is empty or absent**. Two ways to satisfy this:

| If you use…       | Do this                                                                                        |
|-------------------|------------------------------------------------------------------------------------------------|
| **cc-switch**     | Select (or create) a profile whose `"env"` is `{}`. Keep that profile active.                  |
| **No cc-switch**  | Manually edit `~/.claude/settings.json` so the `env` field is `{}` (or remove it entirely).    |

After install, `ccm doctor` checks for this conflict and tells you exactly which keys are in conflict:

```
⚠ /Users/you/.claude/settings.json has a non-empty 'env' block.
  conflicting keys: ANTHROPIC_AUTH_TOKEN, ANTHROPIC_BASE_URL, ANTHROPIC_MODEL, ...
  Those values will OVERRIDE anything ccm sets in the shell.
  Fix: in cc-switch, switch to a profile whose 'env' is {} (empty),
       or edit /Users/you/.claude/settings.json and replace the env block with: "env": {}
```

Until you fix this, **`claude-multi will appear to work but won't actually switch providers** — `ccm use idealab` reports success, but `claude` still goes to whatever provider settings.json pins.

---

## Install

```sh
git clone https://github.com/<your-user>/claude-multi.git ~/.claude-multi
bash ~/.claude-multi/install.sh         # appends a sourced block to ~/.zshrc (or ~/.bashrc)
source ~/.zshrc                          # or open a new terminal
ccm doctor                               # sanity check
```

Then create your provider files (one per supplier):

```sh
ccm add idealab                          # interactive — prompts for URL/token/model
# or copy a template:
cp ~/.claude-multi/providers/idealab.env.example ~/.claude-multi/providers/idealab.env
$EDITOR ~/.claude-multi/providers/idealab.env
ccm reload                               # picks up new files; or open a new terminal
```

---

## Usage

### Primary: `claude-<name>` — start claude with a provider, env stays in this window

```sh
claude-idealab               # injects idealab env into THIS shell, then launches claude
claude-qwen -p "summarize ..."  # all `claude` args are forwarded
claude                        # subsequent bare `claude` calls still use the last provider
claude-idealab                # switch back; same window
```

After running `claude-<name>`, the provider's env is **active in this terminal** until you close it or run `ccm unuse`.

### `ccm use <name>` — set env without launching claude

```sh
ccm use idealab               # only sets env; doesn't start claude
echo $ANTHROPIC_BASE_URL      # https://idealab.alibaba-inc.com/api/anthropic
claude                         # uses idealab
```

### Manage providers

```sh
ccm list                       # list all providers; ✓ marks the one active in this shell
ccm which                      # print active provider name
ccm add <name>                 # interactively create a provider .env
ccm edit <name>                # open the .env in $EDITOR
ccm rm <name>                  # delete a provider
ccm reload                     # re-scan providers/ after manual edits
ccm unuse                      # clear shell env (falls back to settings.json)
ccm doctor                     # diagnose settings.json conflicts, parse errors, etc.
```

### Tab completion (zsh)

```sh
claude-<TAB>                   # completions are real shell functions, zsh handles this for free
ccm use <TAB>                  # → idealab qwen ...
ccm edit <TAB>
```

---

## Provider file format

Plain shell, sourced as-is. Any `ANTHROPIC_*` / `CLAUDE_CODE_*` variable Claude Code understands works — no fixed schema.

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
# ~/.claude-multi/providers/qwen.env (DashScope, Anthropic-compatible)
export ANTHROPIC_AUTH_TOKEN="sk-..."
export ANTHROPIC_BASE_URL="https://dashscope.aliyuncs.com/apps/anthropic"
export ANTHROPIC_MODEL="qwen-latest-series-invite-beta-v34"
export ANTHROPIC_DEFAULT_OPUS_MODEL="qwen-latest-series-invite-beta-v34[1M]"
export ANTHROPIC_DEFAULT_HAIKU_MODEL="qwen-latest-series-invite-beta-v34"
export ANTHROPIC_DEFAULT_SONNET_MODEL="qwen-latest-series-invite-beta-v34"
export CLAUDE_CODE_SUBAGENT_MODEL="qwen-latest-series-invite-beta-v23"
```

Provider files are **gitignored** by default — tokens never get committed. Templates live as `*.env.example`.

---

## File layout

```
~/.claude-multi/
├── init.sh                     # sourced from .zshrc; defines functions + ccm wrapper
├── ccm                         # standalone CLI (list/add/edit/rm/doctor)
├── install.sh                  # idempotent installer (.zshrc append)
├── providers/
│   ├── .gitignore              # ignores *.env (tokens!), keeps *.example
│   ├── idealab.env.example     # template
│   ├── qwen.env.example
│   └── idealab.env             # your real config (gitignored)
└── completions/_ccm            # zsh tab completion
```

---

## Troubleshooting

**`claude-idealab` runs, but `claude` still goes to the old provider.**

Run `ccm doctor`. Almost always: `~/.claude/settings.json` has a non-empty `env` block that's overriding shell env. The doctor output lists exactly which keys conflict.

**Added a new provider file but `claude-newname` doesn't exist.**

Run `ccm reload`, or open a new terminal. Functions are generated when `init.sh` is sourced.

**Want to keep one window on idealab while running a one-shot on qwen.**

Open a new terminal (each terminal has its own env). Or use a subshell explicitly:
```sh
(ccm use qwen && claude -p "hi")     # parentheses isolate env to this subshell
```

**Tokens accidentally committed?**

Don't worry, `providers/*.env` is in `.gitignore` from the start. Only `*.example` files are tracked.

---

## Coexistence with cc-switch

| Tool            | Manages                                           |
|-----------------|---------------------------------------------------|
| **cc-switch**   | `~/.claude/settings.json` — hooks, statusLine, model defaults |
| **claude-multi**| Shell env vars (`ANTHROPIC_*`, `CLAUDE_CODE_*`)   |

Keep cc-switch on a profile with empty `env: {}`, then drive provider selection via claude-multi in each terminal.

---

## License

MIT
