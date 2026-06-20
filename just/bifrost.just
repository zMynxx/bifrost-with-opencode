# ── Bifrost Config, Models & Testing ──────────

# Rebuild bifrost with fresh config (clear SQLite cache)
# ⚠️ Run this after changing bifrost/config.json
refresh:
    docker-compose rm -fs bifrost
    docker-compose up -d bifrost
    echo "Bifrost recreated with fresh config."

# List models available through Bifrost
models:
    curl -s http://localhost:8080/v1/models | python3 -m json.tool

# Send a test chat completion through Bifrost
test msg="Say hello in one word":
    curl -s -X POST http://localhost:8080/v1/chat/completions \
      -H "Content-Type: application/json" \
      -d '{"model":"gpt-4o-mini","messages":[{"role":"user","content":"{{msg}}"}]}' \
      | python3 -m json.tool
