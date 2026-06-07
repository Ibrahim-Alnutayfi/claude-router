# Swarm Integration (Cloude-flow)

Use Claude Router as the upstream proxy for **Claude Swarm** agents running inside Docker containers. Every agent in your swarm routes through the same multi-provider gateway.

## How It Works

```
┌─────────────────┐     ┌──────────────────────┐     ┌─────────────────┐
│  claudeRouter   │────►│  localhost:18765     │────►│  Anthropic API  │
│   --swarm       │     │  (binds 0.0.0.0)     │     │  Codex / GPT    │
└─────────────────┘     └──────────────────────┘     │  Kimi           │
         ▲                                           │  ZAI / GLM      │
         │                                           └─────────────────┘
         │ Docker host gateway
┌────────┴────────┐
│  Docker network │
│  (Cloude-flow)  │
└─────────────────┘
```

## Commands

| Command | What it does |
|---|---|
| `claudeRouter --swarm` | Starts proxy → starts Docker → launches `claude-swarm` inside container. Cleans up everything on exit. |
| `claudeRouter --swarm --off` | Stops Docker containers + kills proxy |
| `claudeRouter --swarm --status` | Shows proxy + Docker status |
| `claudeRouter` | Normal mode (unchanged) |

## One-Time Setup

### 1. Proxy patch (already applied if you followed Setup)

The proxy's `server.ts` must read `CCP_HOST` from the environment:

```typescript
// src/server.ts line ~76
hostname: process.env.CCP_HOST ?? "127.0.0.1",
```

This is included in the `proxy/src/server.ts` patch in this repo.

### 2. Create `docker-compose.proxy.yml` in Cloude-flow

Save this next to your `Cloude-flow/docker-compose.yml`:

```yaml
# docker-compose.proxy.yml
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

## Daily Use

### Start a swarm session

```bash
claudeRouter --swarm
```

What happens:
1. Proxy starts on `0.0.0.0:18765` (Docker-accessible)
2. Cloude-flow containers start with proxy overlay
3. `claude-swarm` launches inside the app container
4. Work with your AI team. Use `/model` to switch providers per agent.
5. When you exit `claude-swarm`, everything auto-cleans up

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

### Stop early

```bash
claudeRouter --swarm --off
```

Stops Docker containers and kills the proxy.

## Security Note

`--swarm` binds the proxy to `0.0.0.0` (all interfaces). On a trusted local network this is low risk. Do **not** use `--swarm` on untrusted networks.
