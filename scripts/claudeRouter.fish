function claudeRouter
    set PROXY_DIR "/Users/ibrahimalnutayfi/Desktop/Desktop - Ibrahim MAC/Tools/claude-code-proxy"
    set PROXY_PORT 18765
    set ZAI_ENV_FILE "$HOME/.config/claude-router/.env"

    # ── Parse flags ──
    set SWARM_MODE false
    set CLAUDE_ARGS
    for arg in $argv
        if test "$arg" = "--swarm"
            set SWARM_MODE true
        else
            set CLAUDE_ARGS $CLAUDE_ARGS $arg
        end
    end

    # ── Kill existing proxy ──
    set PIDS (lsof -t -i:$PROXY_PORT 2>/dev/null)
    if test -n "$PIDS"
        kill -9 $PIDS 2>/dev/null
    end

    # ── Load ZAI key if available ──
    set ZAI_API_KEY ""
    if test -f "$ZAI_ENV_FILE"
        set ZAI_API_KEY (grep '^ZAI_API_KEY=' "$ZAI_ENV_FILE" 2>/dev/null | cut -d= -f2-)
    end

    # ── Swarm mode: bind externally, run proxy in foreground ──
    if test "$SWARM_MODE" = "true"
        echo "Starting proxy in swarm mode (accessible from Docker)..."
        echo "Docker containers should use: http://host.docker.internal:$PROXY_PORT"
        cd "$PROXY_DIR"
        set -e ANTHROPIC_API_KEY 2>/dev/null
        set -e ANTHROPIC_AUTH_TOKEN 2>/dev/null
        env ZAI_API_KEY="$ZAI_API_KEY" CCP_ALIAS_PROVIDER="anthropic" CCP_HOST="0.0.0.0" \
            bun run src/cli.ts serve
        return
    end

    # ── Normal mode ──
    set ORIGINAL_DIR (pwd)
    set -e ANTHROPIC_API_KEY 2>/dev/null
    set -e ANTHROPIC_AUTH_TOKEN 2>/dev/null

    cd "$PROXY_DIR"
    env ZAI_API_KEY="$ZAI_API_KEY" CCP_ALIAS_PROVIDER="anthropic" \
        bun run src/cli.ts serve >/dev/null 2>&1 &

    # ── Wait for proxy to be ready ──
    echo -n "Starting proxy"
    for i in (seq 1 20)
        if lsof -i:$PROXY_PORT >/dev/null 2>&1
            echo " ✓"
            break
        end
        echo -n "."
        sleep 0.25
    end

    cd "$ORIGINAL_DIR"

    set -x ANTHROPIC_BASE_URL "http://localhost:$PROXY_PORT"
    set -x ANTHROPIC_MODEL "sonnet"
    set -x ANTHROPIC_SMALL_FAST_MODEL "haiku"
    set -x CLAUDE_CODE_DISABLE_NONESSENTIAL_TRAFFIC "1"

    claude $CLAUDE_ARGS
end
