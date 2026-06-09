# Swarm Integration (Cloude-flow)

Use Claude Router as the upstream proxy for **Claude Swarm** agents. The swarm runs on your **host machine** (not inside Docker), while Docker provides supporting services (PostgreSQL, Redis).

## How It Works

```
Host machine:
┌─────────────────┐     ┌──────────────────────┐     ┌─────────────────┐
│  claudeRouter   │────►│  localhost:18765     │────►│  Anthropic API  │
│   --swarm       │     │  (shared proxy)      │     │  Codex / GPT    │
└─────────────────┘     └──────────────────────┘     │  Kimi           │
         │                                           │  ZAI / GLM      │
         │                                           └─────────────────┘
         │
         └────► bundle exec exe/claude-swarm (runs on host)

Docker (background):
┌─────────────────┐
│  PostgreSQL     │
│  Redis          │
└─────────────────┘
```

## Commands

| Command | What it does |
|---|---|
| `claudeRouter --swarm` | Starts proxy (or reuses) → starts Docker services → launches `claude-swarm` on host. Stops Docker on exit. Keeps proxy running. |
| `claudeRouter --swarm --off` | Stops Docker services + kills proxy |
| `claudeRouter --swarm --status` | Shows proxy + Docker status |
| `claudeRouter` | Normal mode — reuses existing proxy if running. **Multiple terminals supported.** |

## Prerequisites

1. **Docker Desktop** running (for PostgreSQL/Redis)
2. **rbenv** with Ruby 3.3+ (for claude-swarm gem)
3. **Bundle install** completed in `Cloude-flow/claude-swarm/`

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
2. Docker services (DB, Redis) start in background
3. `claude-swarm` launches on the host
4. Work with your AI team. Use `/model` to switch providers per agent.
5. When you exit `claude-swarm`, Docker services stop automatically
6. Proxy keeps running for normal `claudeRouter` terminals

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
┌─────────────────────────────────────┐
│        Swarm Status                 │
├─────────────────────────────────────┤
│ Proxy:     RUNNING (PID 12345)      │
│ Docker:    RUNNING                  │
└─────────────────────────────────────┘
```

### Stop everything

```bash
claudeRouter --swarm --off
```

## One-Time Setup

Create `docker-compose.proxy.yml` in your `Cloude-flow/` directory:

```yaml
version: '3.8'
services:
  app:
    extra_hosts:
      - "host.docker.internal:host-gateway"
    environment:
      - ANTHROPIC_BASE_URL=http://host.docker.internal:18765
      - ANTHROPIC_MODEL=sonnet
      - ANTHROPIC_SMALL_FAST_MODEL=haiku
      - CLAUDE_CODE_DISABLE_NONESSENTIAL_TRAFFIC=1

  tools:
    extra_hosts:
      - "host.docker.internal:host-gateway"
    environment:
      - ANTHROPIC_BASE_URL=http://host.docker.internal:18765
      - ANTHROPIC_MODEL=sonnet
      - ANTHROPIC_SMALL_FAST_MODEL=haiku
      - CLAUDE_CODE_DISABLE_NONESSENTIAL_TRAFFIC=1
```
