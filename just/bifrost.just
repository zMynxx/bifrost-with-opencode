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
