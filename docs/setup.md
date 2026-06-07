# Setup Guide

## Prerequisites

- macOS (tested on macOS Sonoma/Sequoia)
- [Bun](https://bun.sh) runtime installed
- [Claude Code](https://docs.anthropic.com/en/docs/agents-and-tools/claude-code/overview) installed and authenticated
- Shell: Bash, Zsh, or Fish

## Step 1: Install claude-code-proxy

```bash
git clone https://github.com/anthropics/claude-code-proxy.git ~/Tools/claude-code-proxy
cd ~/Tools/claude-code-proxy
bun install
```

> **Note:** The proxy's `node_modules` must exist. If `bun install` fails, run it again.

## Step 2: Apply Claude Router patches

Copy the patched proxy files from this repo into the proxy:

```bash
cd ~/Tools/claude-code-proxy

# Copy modified files
cp /path/to/claude-router/proxy/src/providers/anthropic/index.ts src/providers/anthropic/
cp /path/to/claude-router/proxy/src/providers/registry.ts src/providers/
cp /path/to/claude-router/proxy/src/providers/types.ts src/providers/
cp /path/to/claude-router/proxy/src/server.ts src/
cp /path/to/claude-router/proxy/src/config.ts src/
cp /path/to/claude-router/proxy/src/providers/codex/auth/token-store.ts src/providers/codex/auth/
cp /path/to/claude-router/proxy/src/providers/kimi/auth/token-store.ts src/providers/kimi/auth/
```

## Step 3: Install launcher scripts

### Bash / Zsh

```bash
mkdir -p ~/bin
cp /path/to/claude-router/scripts/claudeRouter ~/bin/claudeRouter
chmod +x ~/bin/claudeRouter
```

Add to `~/.zshrc` (or `~/.bashrc`):

```bash
export PATH="$HOME/bin:$PATH"
```

Then reload:

```bash
source ~/.zshrc
```

### Fish

```bash
mkdir -p ~/.config/fish/functions
cp /path/to/claude-router/scripts/claudeRouter.fish ~/.config/fish/functions/claudeRouter.fish
```

Fish auto-loads functions — no PATH modification needed.

## Step 4: Configure provider credentials

### ZAI / GLM (optional)

Create the env file:

```bash
mkdir -p ~/.config/claude-router
echo 'ZAI_API_KEY=your-zai-key-here' > ~/.config/claude-router/.env
```

Get your key from [z.ai](https://z.ai).

### Codex / ChatGPT (optional, for GPT models)

```bash
cd ~/Tools/claude-code-proxy
bun run src/cli.ts codex auth login
# Or: claude-code-proxy codex auth login (if linked globally)
```

### Kimi (optional, for Kimi models)

```bash
claude-code-proxy kimi auth login
```

### Anthropic

No extra setup — uses your existing Claude Pro/Max subscription via macOS Keychain.

## Step 5: Test

```bash
# From any project directory
claudeRouter
```

Inside Claude Code:

```
/model sonnet
# → Should work with Anthropic Pro subscription

/model gpt-5.5
# → Should route to Codex (if authenticated)

/model kimi-k2.6
# → Should route to Kimi (if authenticated)

/model glm-5.1
# → Should route to ZAI (if key configured)
```

## What the script does

1. Kills any existing proxy on port 18765
2. Starts `claude-code-proxy` in the background with:
   - `CCP_ALIAS_PROVIDER=anthropic` (routes `sonnet`/`opus`/`haiku` to Anthropic)
   - `ZAI_API_KEY` loaded from `~/.config/claude-router/.env`
3. Waits for the proxy to be ready
4. Launches Claude Code with:
   - `ANTHROPIC_BASE_URL=http://localhost:18765`
   - No leaked `ANTHROPIC_API_KEY` or `ANTHROPIC_AUTH_TOKEN`
   - Working directory preserved (opens your project, not the proxy dir)
