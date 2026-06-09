# Swarm Integration (Cloude-flow)

Use Claude Router as the upstream proxy for **Claude Swarm** agents. Everything runs on your **host machine** — no Docker required.

## How It Works

```
┌─────────────────┐     ┌──────────────────────┐     ┌─────────────────┐
│  claudeRouter   │────►│  localhost:18765     │────►│  Anthropic API  │
│   --swarm       │     │  (shared proxy)      │     │  Codex / GPT    │
└─────────────────┘     └──────────────────────┘     │  Kimi           │
         │                                           │  ZAI / GLM      │
         │                                           └─────────────────┘
         │
         └────► bundle exec exe/claude-swarm (runs on host)
```

## Commands

| Command | What it does |
|---|---|
| `claudeRouter --swarm` | Starts proxy (or reuses) → launches `claude-swarm` on host |
| `claudeRouter --swarm --off` | Kills proxy |
| `claudeRouter --swarm --status` | Shows proxy status |
| `claudeRouter` | Normal mode — reuses existing proxy if running. **Multiple terminals supported.** |

## Prerequisites

1. **rbenv** with Ruby 3.3+ (for claude-swarm gem)
2. **Bundle install** completed in `Cloude-flow/claude-swarm/`

If you haven't installed claude-swarm dependencies yet:

```bash
cd ~/Tools/Cloude-flow/claude-swarm
bundle install
```

## Daily Use

### Start a swarm session

```bash
claudeRouter --swarm
```

What happens:
1. Proxy starts (or reuses existing one)
2. `claude-swarm` launches on the host
3. Work with your AI team. Use `/model` to switch providers per agent.
4. When you exit `claude-swarm`, the proxy keeps running for normal `claudeRouter` terminals

### Open multiple normal terminals

Terminal 1:
```bash
claudeRouter
# → starts proxy + Claude Code
```

Terminal 2:
```bash
claudeRouter
# → reuses existing proxy + opens second Claude Code
```

Both share the same proxy. No conflicts.

### Check status

```bash
claudeRouter --swarm --status
```

Output:
```
┌─────────────────────────────┐
│        Swarm Status         │
├─────────────────────────────┤
│ Proxy:  RUNNING (PID 12345) │
└─────────────────────────────┘
```

### Stop everything

```bash
claudeRouter --swarm --off
```
