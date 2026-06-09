function claudeRouter
    set PROXY_DIR "/Users/ibrahimalnutayfi/Desktop/Desktop - Ibrahim MAC/Tools/claude-code-proxy"
    set CLOUDE_FLOW_DIR "/Users/ibrahimalnutayfi/Desktop/Desktop - Ibrahim MAC/Tools/Cloude-flow"
    set PROXY_PORT 18765
    set ZAI_ENV_FILE "$HOME/.config/claude-router/.env"

    # ── Parse flags ──
    set SWARM_MODE false
    set SWARM_OFF false
    set SWARM_STATUS false
    set CLAUDE_ARGS

    for arg in $argv
        switch "$arg"
            case --swarm
                set SWARM_MODE true
            case --off
                set SWARM_OFF true
            case --status
                set SWARM_STATUS true
            case '*'
                set CLAUDE_ARGS $CLAUDE_ARGS $arg
        end
    end

    # ── Load ZAI key if available ──
    set ZAI_API_KEY ""
    if test -f "$ZAI_ENV_FILE"
        set ZAI_API_KEY (grep '^ZAI_API_KEY=' "$ZAI_ENV_FILE" 2>/dev/null | cut -d= -f2-)
    end

    # ═══════════════════════════════════════════════════════════════
    # SWARM STATUS
    # ═══════════════════════════════════════════════════════════════
    if test "$SWARM_STATUS" = "true"
        echo "┌─────────────────────────────────────┐"
        echo "│        Swarm Status                 │"
        echo "├─────────────────────────────────────┤"

        set PIDS (lsof -t -i:$PROXY_PORT 2>/dev/null)
        if test -n "$PIDS"
            echo "│ Proxy:     RUNNING (PID $PIDS)      │"
        else
            echo "│ Proxy:     STOPPED                  │"
        end

        set DOCKER_UP (docker-compose -f "$CLOUDE_FLOW_DIR/docker-compose.yml" -f "$CLOUDE_FLOW_DIR/docker-compose.proxy.yml" ps 2>/dev/null | grep -c "Up" 2>/dev/null)
        if test "$DOCKER_UP" -gt 0
            echo "│ Docker:    RUNNING                  │"
        else
            echo "│ Docker:    STOPPED                  │"
        end

        echo "└─────────────────────────────────────┘"
        return
    end

    # ═══════════════════════════════════════════════════════════════
    # SWARM OFF
    # ═══════════════════════════════════════════════════════════════
    if test "$SWARM_OFF" = "true"
        echo "Stopping swarm..."
        cd "$CLOUDE_FLOW_DIR"
        docker-compose -f docker-compose.yml -f docker-compose.proxy.yml down 2>/dev/null
        set PIDS (lsof -t -i:$PROXY_PORT 2>/dev/null)
        if test -n "$PIDS"
            kill -9 $PIDS 2>/dev/null
        end
        echo "Swarm stopped."
        return
    end

    # ═══════════════════════════════════════════════════════════════
    # SWARM ON (managed session)
    # ═══════════════════════════════════════════════════════════════
    if test "$SWARM_MODE" = "true"
        echo "Starting swarm session..."

        # Kill existing proxy
        set PIDS (lsof -t -i:$PROXY_PORT 2>/dev/null)
        if test -n "$PIDS"
            kill -9 $PIDS 2>/dev/null
        end

        # Start proxy in background
        cd "$PROXY_DIR"
        set -e ANTHROPIC_API_KEY 2>/dev/null
        set -e ANTHROPIC_AUTH_TOKEN 2>/dev/null
        env ZAI_API_KEY="$ZAI_API_KEY" CCP_ALIAS_PROVIDER="anthropic" CCP_HOST="0.0.0.0" \
            bun run src/cli.ts serve >/dev/null 2>&1 &

        # Wait for proxy
        echo -n "Starting proxy"
        for i in (seq 1 20)
            if lsof -i:$PROXY_PORT >/dev/null 2>&1
                echo " ✓"
                break
            end
            echo -n "."
            sleep 0.25
        end

        # Verify Docker is running
        if not docker info >/dev/null 2>&1
            echo ""
            echo "❌ Docker is not running. Start Docker Desktop first:"
            echo "   open -a Docker"
            return 1
        end

        # Start Docker containers
        cd "$CLOUDE_FLOW_DIR"
        echo "Starting Cloude-flow containers..."
        docker-compose -f docker-compose.yml -f docker-compose.proxy.yml up -d

        # Launch claude-swarm inside container
        echo "Launching claude-swarm (press Ctrl+D or type /exit to quit)..."
        docker-compose -f docker-compose.yml -f docker-compose.proxy.yml exec -it app claude-swarm
        set SWARM_EXIT $status

        # Cleanup
        echo ""
        echo "Stopping swarm session..."
        docker-compose -f docker-compose.yml -f docker-compose.proxy.yml down 2>/dev/null
        set PIDS (lsof -t -i:$PROXY_PORT 2>/dev/null)
        if test -n "$PIDS"
            kill -9 $PIDS 2>/dev/null
        end
        echo "Swarm stopped."
        return $SWARM_EXIT
    end

    # ═══════════════════════════════════════════════════════════════
    # NORMAL MODE
    # ═══════════════════════════════════════════════════════════════

    # Kill existing proxy
    set PIDS (lsof -t -i:$PROXY_PORT 2>/dev/null)
    if test -n "$PIDS"
        kill -9 $PIDS 2>/dev/null
    end

    # Load ZAI key
    if test -f "$ZAI_ENV_FILE"
        set ZAI_API_KEY (grep '^ZAI_API_KEY=' "$ZAI_ENV_FILE" 2>/dev/null | cut -d= -f2-)
    end

    set ORIGINAL_DIR (pwd)
    set -e ANTHROPIC_API_KEY 2>/dev/null
    set -e ANTHROPIC_AUTH_TOKEN 2>/dev/null

    cd "$PROXY_DIR"
    env ZAI_API_KEY="$ZAI_API_KEY" CCP_ALIAS_PROVIDER="anthropic" \
        bun run src/cli.ts serve >/dev/null 2>&1 &

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
