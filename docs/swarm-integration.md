# Swarm Integration (Cloude-flow)

Use Claude Router as the upstream proxy for **Claude Swarm** agents running inside Docker containers. This lets every agent in your swarm route through the same multi-provider gateway — so your `lead_developer` can use Anthropic, your `frontend_dev` can use Kimi, and your `backend_dev` can use Codex, all orchestrated by Cloude-flow.

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

## Wire (One-Time Setup)

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

## Run (Every Session)

### Step 1: Start the proxy in swarm mode

In a **dedicated terminal**:

```bash
claudeRouter --swarm
```

You'll see:
```
Starting proxy in swarm mode (accessible from Docker)...
Docker containers should use: http://host.docker.internal:18765
```

The proxy now binds to `0.0.0.0:18765` so Docker can reach it.

### Step 2: Start Cloude-flow with the proxy overlay

In another terminal:

```bash
cd ~/Tools/Cloude-flow
docker-compose -f docker-compose.yml -f docker-compose.proxy.yml up -d
```

Or if you prefer the helper script, modify `docker-scripts.sh` to include the extra compose file:

```bash
# In docker-scripts.sh, change all docker-compose commands to:
docker-compose -f docker-compose.yml -f docker-compose.proxy.yml ...
```

### Step 3: Enter the container and run the swarm

```bash
cd ~/Tools/Cloude-flow
./docker-scripts.sh shell
# Inside container:
claude-swarm
```

Every agent in your `claude-swarm.yml` will now route through your proxy. You can configure individual agents to use different models via `/model` inside each agent's session.

## Unwire (When Done)

### Step 1: Stop Cloude-flow

```bash
cd ~/Tools/Cloude-flow
./docker-scripts.sh stop
```

### Step 2: Stop the proxy

In the terminal running `claudeRouter --swarm`, press **Ctrl+C**.

### Step 3: (Optional) Remove the compose overlay

```bash
rm ~/Tools/Cloude-flow/docker-compose.proxy.yml
```

Normal `claudeRouter` (without `--swarm`) continues to work exactly as before — it binds to `127.0.0.1` only.

## Security Note

`--swarm` binds the proxy to `0.0.0.0` (all interfaces). On a trusted local network this is low risk since it's a high port (18765) with no sensitive data stored. Do **not** use `--swarm` on untrusted networks.
