# ── Bifrost Config, Models & Testing ──────────

# Rebuild bifrost with fresh config (clear SQLite cache)
# ⚠️ Run this after changing bifrost/config.json
refresh:
    docker-compose rm -fs bifrost
    docker-compose up -d bifrost
    echo "Bifrost recreated with fresh config."

# List models and update OpenCode CLI config with discovered providers/models
models:
    bifrost/discover-models.py

# Discover models from all Bifrost providers and auto-update CLI config
#   just discover-models                  # list & save to .bifrost/config.json
#   just discover-models model="github-copilot/gpt-4o-mini"  # list + set as default
discover-models model="":
    #!/usr/bin/env bash
    if [ -z "{{model}}" ]; then
      bifrost/discover-models.py
    else
      bifrost/discover-models.py --set-default "{{model}}"
    fi

# Discover models filtered by provider
discover-models-provider provider="github-copilot":
    bifrost/discover-models.py --provider '{{provider}}'

# Raw JSON output of discovered models
discover-models-json:
    bifrost/discover-models.py --json

# ── Meridian (Claude Max proxy via Anthropic API) ──

# Build Meridian Docker image (one-time, or after version bumps)
meridian-build:
    docker-compose build meridian

# Start Meridian container (via docker-compose)
meridian-up:
    docker-compose up -d meridian
    echo "Waiting for Meridian..."
    sleep 4
    curl -s http://127.0.0.1:3456/health | python3 -m json.tool || echo "⏳ Still starting..."

# Stop Meridian container
meridian-stop:
    docker-compose stop meridian

# Auth check: verify the host Claude session is mounted and valid
#   Run this after 'just meridian-up'
#   Credentials are mounted from the host's ~/.claude directory
#   Requires 'claude login' on the host machine (one-time)
meridian-auth:
    #!/usr/bin/env bash
    echo "Checking Claude auth on host..."
    if command -v claude &>/dev/null; then
      claude auth status 2>/dev/null && echo "✅ Host Claude session OK" || echo "⚠ Run 'claude login' first"
    else
      echo "⚠ Claude CLI not found on host (credentials directory will be mounted as-is)"
    fi
    echo ""
    echo "Meridian container mounts: ~/.claude → /home/claude/.claude"
    echo "Start Meridian and verify: just meridian-status"

# Check Meridian status
meridian-status:
    curl -s http://127.0.0.1:3456/health | python3 -m json.tool 2>/dev/null || echo "Meridian not running"

# ── Testing ─────────────────────────────────────

# Send a test chat completion through Bifrost
#   just test                                      # uses gpt-4o-mini
#   just test msg="hello" model="github-copilot/gpt-4o"
#   just test model="anthropic/claude-sonnet-4-20250514"
#   just test model="openai/gpt-4o"
#   just test model="bedrock/anthropic.claude-sonnet-4-20250514-v1:0"
test msg="Say hello in one word" model="github-copilot/gpt-4o-mini":
    curl -s -X POST http://localhost:8080/v1/chat/completions \
      -H "Content-Type: application/json" \
      -d '{"model":"{{model}}","messages":[{"role":"user","content":"{{msg}}"}]}' \
      | python3 -m json.tool
