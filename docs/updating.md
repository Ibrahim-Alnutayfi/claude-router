# Updating Guide

## Update the proxy (claude-code-proxy)

```bash
cd ~/Tools/claude-code-proxy
git pull origin main
bun install
```

**After updating:** Re-apply the Claude Router patches (they will be overwritten by `git pull`):

```bash
cd ~/Tools/claude-code-proxy

# Re-apply all patches from this repo
cp /path/to/claude-router/proxy/src/providers/anthropic/index.ts src/providers/anthropic/
cp /path/to/claude-router/proxy/src/providers/registry.ts src/providers/
cp /path/to/claude-router/proxy/src/providers/types.ts src/providers/
cp /path/to/claude-router/proxy/src/server.ts src/
cp /path/to/claude-router/proxy/src/config.ts src/
cp /path/to/claude-router/proxy/src/providers/codex/auth/token-store.ts src/providers/codex/auth/
cp /path/to/claude-router/proxy/src/providers/kimi/auth/token-store.ts src/providers/kimi/auth/
```

## Update provider credentials

### Refresh Anthropic OAuth

If you get "Invalid bearer token", your token may be expired:

```bash
claude auth login
# Or use the existing Claude Code login flow
```

### Refresh Kimi OAuth

```bash
claude-code-proxy kimi auth login
```

### Refresh Codex OAuth

```bash
claude-code-proxy codex auth login
```

### Update ZAI key

Edit `~/.claude/gateway/.env`:

```bash
echo 'ZAI_API_KEY=new-key-here' > ~/.claude/gateway/.env
```

## Update claudeRouter scripts

If you modify the scripts in this repo, reinstall them:

```bash
# Bash
cp scripts/claudeRouter ~/bin/claudeRouter

# Fish
cp scripts/claudeRouter.fish ~/.config/fish/functions/claudeRouter.fish
```

## Update this repo

```bash
cd /path/to/claude-router
git add .
git commit -m "Update patches / scripts / docs"
git push origin main
```

## Check for new models

If Anthropic, OpenAI, or other providers release new models, update the aliases in `proxy/src/providers/registry.ts`.
