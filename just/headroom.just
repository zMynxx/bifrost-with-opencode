# ── Headroom AI Context Compression ───────────

# Check headroom health
headroom-health:
    curl -s http://localhost:8787/health | python3 -m json.tool

# Headroom compression stats
headroom-stats:
    curl -s http://localhost:8787/stats | python3 -m json.tool

# Headroom compression history
headroom-history:
    curl -s "http://localhost:8787/stats-history?format=json" | python3 -m json.tool

# Install Headroom MCP server so OpenCode can use headroom_compress / headroom_retrieve
# Requires: pip install "headroom-ai[mcp]"
headroom-mcp-install:
    headroom mcp install

# Test chat through Headroom proxy (compresses then routes through Bifrost)
headroom-test msg="Say hello in one word" model="anthropic/claude-haiku-4-5":
    curl -s -X POST http://localhost:8787/v1/chat/completions \
      -H "Content-Type: application/json" \
      -d '{"model":"{{model}}","messages":[{"role":"user","content":"{{msg}}"}]}' \
      | python3 -m json.tool

# Tail Headroom logs
headroom-logs:
    docker-compose logs --tail=50 -f headroom

# Install headroom-ai Python package locally (for MCP, proxy CLI, or library use)
headroom-install-python:
    pip install "headroom-ai[proxy,mcp]"
