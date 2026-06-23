# ── Bifrost Config, Models & Testing ──────────

# Rebuild bifrost with fresh config (clear SQLite cache)
# ⚠️ Run this after changing bifrost/config.json
refresh:
    docker-compose rm -fs bifrost
    docker-compose up -d bifrost
    echo "Bifrost recreated with fresh config."

# List models available through Bifrost (raw API output)
models:
    curl -s http://localhost:8080/v1/models | python3 -m json.tool

# Discover models from all Bifrost providers and auto-update CLI config
#   just discover-models                  # list & save to ~/.bifrost/config.json
#   just discover-models model="github-models/claude-sonnet-4.6"  # list + set as default
discover-models model="":
    #!/usr/bin/env bash
    if [ -z "{{model}}" ]; then
      bifrost/discover-models.py
    else
      bifrost/discover-models.py --set-default "{{model}}"
    fi

# Discover models filtered by provider
discover-models-provider provider="github":
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

# One-time auth: generate a token from your host Claude session and add it
#   Run this ONCE after 'just meridian-up'
#   (Requires 'claude' authenticated on the host machine)
meridian-auth:
    #!/usr/bin/env bash
    set -e
    TOKEN=$(claude setup-token 2>/dev/null) || {
      echo "❌ 'claude setup-token' failed. Is Claude installed and logged in?"
      echo "   Run: npm install -g @anthropic-ai/claude-code && claude login"
      exit 1
    }
    docker exec -i meridian meridian profile add --oauth-token "$TOKEN"
    echo "✅ Meridian authenticated with Claude Max"
    echo "   Restart to pick up the profile: docker-compose restart meridian"

# Check Meridian status
meridian-status:
    curl -s http://127.0.0.1:3456/health | python3 -m json.tool 2>/dev/null || echo "Meridian not running"

# ── Testing ─────────────────────────────────────

# Send a test chat completion through Bifrost (default: github-models)
#   just test                                      # uses gpt-4o-mini
#   just test msg="hello" model="github-models/claude-sonnet-4.6"
#   just test model="meridian-claude/claude-sonnet-4-6"
test msg="Say hello in one word" model="github-models/gpt-4o-mini":
    curl -s -X POST http://localhost:8080/v1/chat/completions \
      -H "Content-Type: application/json" \
      -d '{"model":"{{model}}","messages":[{"role":"user","content":"{{msg}}"}]}' \
      | python3 -m json.tool
