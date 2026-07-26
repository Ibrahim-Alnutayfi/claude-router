function claudeRouter
    set PROXY_DIR "/Users/inutayfi/Desktop/LLMs/claude-code-proxy"
    set CLOUDE_FLOW_DIR "/Users/inutayfi/Desktop/LLMs/claude-flow"
    set CLAUDE_SWARM_DIR "/Users/inutayfi/Desktop/LLMs/claude-swarm"
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
        echo "┌─────────────────────────────┐"
        echo "│        Swarm Status         │"
        echo "├─────────────────────────────┤"

        set PIDS (lsof -t -n -P -i:$PROXY_PORT 2>/dev/null)
        if test -n "$PIDS"
            echo "│ Proxy:  RUNNING (PID $PIDS) │"
        else
            echo "│ Proxy:  STOPPED             │"
        end

        echo "└─────────────────────────────┘"
        return
    end

    # ═══════════════════════════════════════════════════════════════
    # SWARM OFF
    # ═══════════════════════════════════════════════════════════════
    if test "$SWARM_OFF" = "true"
        echo "Stopping swarm..."
        set PIDS (lsof -t -n -P -i:$PROXY_PORT 2>/dev/null)
        if test -n "$PIDS"
            kill -9 $PIDS 2>/dev/null
        end
        echo "Swarm stopped."
        return
    end

    # ═══════════════════════════════════════════════════════════════
    # HELPER: ensure proxy is running
    # ═══════════════════════════════════════════════════════════════
    function _ensure_proxy -a PROXY_PORT PROXY_DIR ZAI_API_KEY
        if lsof -n -P -i:$PROXY_PORT >/dev/null 2>&1
            echo "Proxy already running on port $PROXY_PORT (reusing)"
            return 0
        end

        pushd "$PROXY_DIR" >/dev/null
        set -e ANTHROPIC_API_KEY 2>/dev/null
        set -e ANTHROPIC_AUTH_TOKEN 2>/dev/null
        set -q CCP_CODEX_TRANSPORT; or set CCP_CODEX_TRANSPORT auto
        env ZAI_API_KEY="$ZAI_API_KEY" CCP_ALIAS_PROVIDER="codex" \
            CCP_CODEX_TRANSPORT="$CCP_CODEX_TRANSPORT" \
            ./target/release/claude-code-proxy serve >/dev/null 2>&1 &
        popd >/dev/null

        echo -n "Starting proxy"
        for i in (seq 1 20)
            if lsof -n -P -i:$PROXY_PORT >/dev/null 2>&1
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
    # SWARM ON (host-based, no Docker)
    # ═══════════════════════════════════════════════════════════════
    if test "$SWARM_MODE" = "true"
        echo "Starting swarm session..."

        _ensure_proxy $PROXY_PORT $PROXY_DIR "$ZAI_API_KEY"
        or exit 1

        # Run claude-swarm on the HOST
        echo "Launching claude-swarm (press Ctrl+D or type /exit to quit)..."
        cd "$CLAUDE_SWARM_DIR"
        set -e ANTHROPIC_MODEL 2>/dev/null
        env ANTHROPIC_BASE_URL="http://127.0.0.1:$PROXY_PORT" \
            ANTHROPIC_SMALL_FAST_MODEL="haiku" \
            CLAUDE_CODE_DISABLE_NONESSENTIAL_TRAFFIC="1" \
            claude-swarm
        set SWARM_EXIT $status

        echo "Swarm session ended."
        return $SWARM_EXIT
    end

    # ═══════════════════════════════════════════════════════════════
    # NORMAL MODE (supports multiple concurrent terminals)
    # ═══════════════════════════════════════════════════════════════

    _ensure_proxy $PROXY_PORT $PROXY_DIR "$ZAI_API_KEY"
    or exit 1

    set ORIGINAL_DIR (pwd)
    cd "$ORIGINAL_DIR"

    set -e ANTHROPIC_API_KEY 2>/dev/null
    set -e ANTHROPIC_AUTH_TOKEN 2>/dev/null

    set -x ANTHROPIC_BASE_URL "http://127.0.0.1:$PROXY_PORT"
    set -x ANTHROPIC_MODEL "claude-sonnet-5"
    set -x ANTHROPIC_SMALL_FAST_MODEL "haiku"
    set -x CLAUDE_CODE_DISABLE_NONESSENTIAL_TRAFFIC "1"

    claude $CLAUDE_ARGS
end
