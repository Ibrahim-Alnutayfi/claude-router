function claudeRouter
    set PROXY_DIR "/Users/ibrahimalnutayfi/Desktop/Desktop - Ibrahim MAC/Tools/claude-code-proxy"
    set CLOUDE_FLOW_DIR "/Users/ibrahimalnutayfi/Desktop/Desktop - Ibrahim MAC/Tools/Cloude-flow"
    set PROXY_PORT 18765
    set ZAI_ENV_FILE "$HOME/.config/claude-router/.env"

    # Initialize rbenv if available
    if test -d "$HOME/.rbenv/shims"
        set PATH "$HOME/.rbenv/shims" $PATH
        rbenv init - fish 2>/dev/null | source 2>/dev/null
    end

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
    # HELPER: ensure proxy is running
    # ═══════════════════════════════════════════════════════════════
    function _ensure_proxy
        if lsof -i:$PROXY_PORT >/dev/null 2>&1
            echo "Proxy already running on port $PROXY_PORT (reusing)"
            return 0
        end

        cd "$PROXY_DIR"
        set -e ANTHROPIC_API_KEY 2>/dev/null
        set -e ANTHROPIC_AUTH_TOKEN 2>/dev/null
        env ZAI_API_KEY="$ZAI_API_KEY" CCP_ALIAS_PROVIDER="anthropic" \
            bun run src/cli.ts serve >/dev/null 2>&1 &

        echo -n "Starting proxy"
        for i in (seq 1 20)
            if lsof -i:$PROXY_PORT >/dev/null 2>&1
                echo " ✓"
                return 0
            end
            echo -n "."
            sleep 0.25
        end
        echo " ✗ (timeout)"
        return 1
    end

    # ═══════════════════════════════════════════════════════════════
    # SWARM ON (managed session)
    # ═══════════════════════════════════════════════════════════════
    if test "$SWARM_MODE" = "true"
        echo "Starting swarm session..."

        _ensure_proxy
        or exit 1

        # Verify Docker is running
        if not docker info >/dev/null 2>&1
            echo ""
            echo "❌ Docker is not running. Start Docker Desktop first:"
            echo "   open -a Docker"
            return 1
        end

        # Start Docker services
        cd "$CLOUDE_FLOW_DIR"
        echo "Starting Cloude-flow services..."
        docker-compose -f docker-compose.yml -f docker-compose.proxy.yml up -d

        # Run claude-swarm on the HOST
        echo "Launching claude-swarm (press Ctrl+D or type /exit to quit)..."
        cd "$CLOUDE_FLOW_DIR/claude-swarm"
        env ANTHROPIC_BASE_URL="http://localhost:$PROXY_PORT" \
            ANTHROPIC_MODEL="sonnet" \
            ANTHROPIC_SMALL_FAST_MODEL="haiku" \
            CLAUDE_CODE_DISABLE_NONESSENTIAL_TRAFFIC="1" \
            bundle exec exe/claude-swarm
        set SWARM_EXIT $status

        # Stop Docker services (keep proxy running for normal terminals)
        echo ""
        echo "Stopping Cloude-flow services..."
        cd "$CLOUDE_FLOW_DIR"
        docker-compose -f docker-compose.yml -f docker-compose.proxy.yml down 2>/dev/null
        echo "Swarm stopped."
        return $SWARM_EXIT
    end

    # ═══════════════════════════════════════════════════════════════
    # NORMAL MODE (supports multiple concurrent terminals)
    # ═══════════════════════════════════════════════════════════════

    _ensure_proxy
    or exit 1

    set ORIGINAL_DIR (pwd)
    cd "$ORIGINAL_DIR"

    set -e ANTHROPIC_API_KEY 2>/dev/null
    set -e ANTHROPIC_AUTH_TOKEN 2>/dev/null

    set -x ANTHROPIC_BASE_URL "http://localhost:$PROXY_PORT"
    set -x ANTHROPIC_MODEL "sonnet"
    set -x ANTHROPIC_SMALL_FAST_MODEL "haiku"
    set -x CLAUDE_CODE_DISABLE_NONESSENTIAL_TRAFFIC "1"

    claude $CLAUDE_ARGS
end
