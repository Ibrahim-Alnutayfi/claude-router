function claudeRouter
    set PROXY_DIR "/Users/ibrahimalnutayfi/Desktop/Desktop - Ibrahim MAC/Tools/claude-code-proxy"
    set PROXY_PORT 18765
    set ZAI_ENV_FILE "$HOME/.claude/gateway/.env"

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

    # ── Remember where we are ──
    set ORIGINAL_DIR (pwd)

    # Clean leaked auth vars before starting proxy so it doesn't pick them up
    set -e ANTHROPIC_API_KEY 2>/dev/null
    set -e ANTHROPIC_AUTH_TOKEN 2>/dev/null

    # ── Start proxy in background ──
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

    # ── Launch Claude Code from original directory ──
    cd "$ORIGINAL_DIR"

    set -x ANTHROPIC_BASE_URL "http://localhost:$PROXY_PORT"
    set -x ANTHROPIC_MODEL "sonnet"
    set -x ANTHROPIC_SMALL_FAST_MODEL "haiku"
    set -x CLAUDE_CODE_DISABLE_NONESSENTIAL_TRAFFIC "1"

    claude $argv
end
