# Claude Router

A multi-provider proxy gateway for [Claude Code](https://docs.anthropic.com/en/docs/agents-and-tools/claude-code/overview) that lets you seamlessly switch between Anthropic, OpenAI (Codex), Kimi, and ZAI/GLM models in a single session — all through Claude Code's native `/model` command.

## What It Does

Claude Router starts a local proxy server and launches Claude Code with the correct environment. When you type `/model gpt-5.5`, `/model kimi-k2.6`, or `/model sonnet`, the proxy routes each request to the correct upstream provider.

| Model Alias | Provider | Auth Required |
|---|---|---|
| `sonnet`, `opus`, `haiku` | **Anthropic** | Claude Pro/Max OAuth (macOS Keychain) |
| `gpt-5.5`, `gpt-5.4`, etc. | **OpenAI Codex** | `codex login` |
| `kimi-k2.6`, `kimi-for-coding` | **Kimi** | `claude-code-proxy kimi auth login` |
| `glm-5.1`, `glm-4-plus`, etc. | **ZAI / GLM** | `ZAI_API_KEY` env var |

## Quick Start

```bash
# 1. Clone this repo
git clone <your-remote-url> claude-router
cd claude-router

# 2. Install the proxy dependency
git clone https://github.com/anthropics/claude-code-proxy.git ../claude-code-proxy
cd ../claude-code-proxy
bun install

# 3. Apply the patches from this repo
# (Copy proxy/ files into claude-code-proxy/src/)

# 4. Install the launcher script
# Bash (macOS/Linux)
mkdir -p ~/bin
cp scripts/claudeRouter ~/bin/claudeRouter
chmod +x ~/bin/claudeRouter
# Add ~/bin to PATH in ~/.zshrc if needed

# Fish shell
mkdir -p ~/.config/fish/functions
cp scripts/claudeRouter.fish ~/.config/fish/functions/claudeRouter.fish

# 5. Set your ZAI key (optional, for GLM models)
echo 'ZAI_API_KEY=your-key-here' > ~/.config/claude-router/.env

# 6. Authenticate providers you want to use
claude-code-proxy codex auth login      # For GPT/Codex models
claude-code-proxy kimi auth login       # For Kimi models
# Anthropic uses your existing Claude Pro/Max login

# 7. Run
claudeRouter
```

See [docs/setup.md](docs/setup.md) for the full step-by-step guide.

## Debugging

If something breaks, see [docs/debugging.md](docs/debugging.md) for a systematic troubleshooting guide based on real issues we've solved.

## Updating

See [docs/updating.md](docs/updating.md) for how to update the proxy, scripts, or provider auth.

## Architecture

```
Claude Code ──► localhost:18765 (proxy) ──► provider routing ──► upstream API
                  │
                  ├── Anthropic ──► api.anthropic.com (OAuth Bearer + oauth beta)
                  ├── Codex ──────► ChatGPT websocket (codex CLI auth)
                  ├── Kimi ───────► api.kimi.com (OAuth)
                  └── ZAI ────────► api.z.ai (API key)
```

## License

MIT — modify and share freely.
