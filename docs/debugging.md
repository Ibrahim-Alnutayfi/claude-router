# Debugging Guide

## Symptom: "Invalid bearer token" with Anthropic

### Check 1: Is the proxy sending OAuth correctly?

OAuth tokens (`sk-ant-oat*`) must be sent as:
- Header: `Authorization: Bearer sk-ant-oat...`
- Header: `anthropic-beta: oauth-2025-04-20` (or appended to existing beta flags)

NOT as `x-api-key`. The `anthropic-beta: oauth-2025-04-20` is required.

### Check 2: Is auth leaking into the proxy subshell?

**Root cause:** If `ANTHROPIC_API_KEY` or `ANTHROPIC_AUTH_TOKEN` is set when the proxy starts, the proxy's internal auth logic may conflict with the OAuth token from the client.

**Fix:** The `claudeRouter` script unsets these variables **before** starting the proxy:

```bash
(
  cd "$PROXY_DIR" || exit 1
  unset ANTHROPIC_API_KEY 2>/dev/null
  unset ANTHROPIC_AUTH_TOKEN 2>/dev/null
  bun run src/cli.ts serve >/dev/null 2>&1 &
)
```

### Check 3: Verify the token type

```bash
security find-generic-password -s "Claude Code - Anthropic" -w | head -c 30
```

Should start with `sk-ant-oat` (OAuth), NOT `sk-ant-api03` (API key).

### Check 4: Test auth manually

```bash
security find-generic-password -s "Claude Code - Anthropic" -w | \
  xargs -I {} curl -s -o /dev/null -w "%{http_code}" \
  -H "Authorization: Bearer {}" \
  -H "anthropic-beta: oauth-2025-04-20" \
  https://api.anthropic.com/v1/models
```

Should return `200`. If `401`, your token is expired — run `claude auth login`.

---

## Symptom: "This model is not available to you" or "Invalid model"

### Check 1: Model name conversion

If Anthropic aliases (like `claude-sonnet-4-6`) are being converted to dated snapshots (like `claude-sonnet-4-20250514`), the dated snapshots don't support the `effort` parameter.

**Fix:** Pass model names through unchanged. The patched `anthropic/index.ts` does this by removing ALIAS_MAP conversion.

### Check 2: Codex models

Codex only supports specific models (see `src/config.ts`). If you request an unsupported model, you'll get an error.

---

## Symptom: Proxy starts but Claude Code can't connect

### Check 1: Is the proxy actually running?

```bash
curl -s http://localhost:18765/health || echo "Proxy not responding"
```

### Check 2: Port conflict

```bash
lsof -i:18765
# Kill any stale processes
kill -9 $(lsof -t -i:18765)
```

### Check 3: Check proxy logs

```bash
tail -f ~/.local/state/claude-code-proxy/proxy.log
```

Look for:
- Startup errors
- Auth header format
- Which provider is being used

---

## Symptom: Kimi or Codex models fail

### Check 1: Is the provider authenticated?

```bash
# Check Codex auth
ls ~/.codex/

# Check Kimi auth
cat ~/.claude-code-proxy/kimi/credentials.json
```

### Check 2: Re-authenticate

```bash
claude-code-proxy codex auth login
claude-code-proxy kimi auth login
```

### Check 3: Check token store patches

The original proxy stores tokens in the wrong location. The patched `token-store.ts` files fix this. Verify the patches are applied.

---

## Symptom: GLM/ZAI models fail

### Check 1: Is ZAI_API_KEY set?

```bash
echo $ZAI_API_KEY
# Should print your key
```

If empty, check `~/.config/claude-router/.env` exists and the script sources it.

---

## Symptom: Claude Code opens in wrong directory

The `claudeRouter` script saves `$(pwd)` before `cd` into the proxy directory, then restores it before launching Claude Code. If it opens in the proxy directory instead of your project, the `cd` back failed.

Check the script has:

```bash
ORIGINAL_DIR="$(pwd)"
# ... start proxy ...
cd "$ORIGINAL_DIR"
claude "$@"
```

---

## General troubleshooting steps

1. **Kill everything and restart:**
   ```bash
   kill -9 $(lsof -t -i:18765) 2>/dev/null
   claudeRouter
   ```

2. **Check which provider Claude Code is hitting:**
   ```bash
   # In another terminal
   tail -f ~/.local/state/claude-code-proxy/proxy.log
   ```

3. **Verify auth headers:**
   Add logging in `src/providers/anthropic/index.ts` to print headers.

4. **Test provider directly:**
   ```bash
   # Test Anthropic
   curl https://api.anthropic.com/v1/models -H "Authorization: Bearer YOUR_TOKEN" -H "anthropic-beta: oauth-2025-04-20"
   
   # Test Codex
   codex models
   ```
