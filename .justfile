# ─────────────────────────────────────────────────────
# Bifrost + OpenTelemetry + ClickHouse + Headroom
# ─────────────────────────────────────────────────────

# Use Podman socket (not Docker Desktop)
export DOCKER_HOST := "unix:///var/run/docker.sock"
export DOCKER_CONFIG := "/tmp"

# ── Service Management ────────────────────────────────

# Start all services
up:
    docker-compose up -d
    echo "Waiting for services to be healthy..."
    sleep 12
    docker-compose ps

# Stop all services (keep data volumes)
down:
    docker-compose down

# Full reset — remove containers + all data volumes
reset:
    docker-compose down -v
    echo "All containers and volumes removed."

# Show container status
ps:
    docker-compose ps

# Tail logs for a service (usage: just logs [service])
logs service="bifrost":
    docker-compose logs --tail=50 -f {{service}}

# Restart a specific service (usage: just restart [service])
restart service="bifrost":
    docker-compose restart {{service}}

# ── Config Management ────────────────────────────────

# Rebuild bifrost with fresh config (clear SQLite cache)
# ⚠️ Run this after changing bifrost/config.json
refresh:
    docker-compose rm -fs bifrost
    docker-compose up -d bifrost
    echo "Bifrost recreated with fresh config."

# ── Models ──────────────────────────────────────────

# List models available through Bifrost
models:
    curl -s http://localhost:8080/v1/models | python3 -m json.tool

# ── Testing ──────────────────────────────────────────

# Send a test chat completion through Bifrost
test msg="Say hello in one word":
    curl -s -X POST http://localhost:8080/v1/chat/completions \
      -H "Content-Type: application/json" \
      -d '{"model":"gpt-4o-mini","messages":[{"role":"user","content":"{{msg}}"}]}' \
      | python3 -m json.tool

# ── Observability ────────────────────────────────────

# Show recent traces in ClickHouse
traces limit="10":
    curl -s "http://localhost:8123" \
      --data-urlencode "SELECT Timestamp, SpanName, Duration, StatusCode \
                        FROM otel.otel_traces \
                        ORDER BY Timestamp DESC LIMIT {{limit}}" \
      --data-urlencode "default_format=PrettyCompact" \
      | sed 's/^[ \t]*//'

# Count total traces
traces-count:
    curl -s "http://localhost:8123" \
      --data-urlencode "SELECT count(*) AS total_traces FROM otel.otel_traces" \
      --data-urlencode "default_format=PrettyCompact"

# Check telemetry tables exist in ClickHouse
schema:
    curl -s "http://localhost:8123" \
      --data-urlencode "SHOW TABLES FROM otel" \
      --data-urlencode "default_format=PrettyCompact"

# ── Diagnostics ──────────────────────────────────────

# Health check all services
check:
    echo "=== Bifrost ==="
    curl -s -o /dev/null -w "HTTP %{http_code}\n" http://localhost:8080/health
    echo "=== ClickHouse ==="
    curl -s -o /dev/null -w "HTTP %{http_code}\n" http://localhost:8123/ping

    echo "=== OTel Collector ==="
    curl -s -o /dev/null -w "HTTP %{http_code}\n" http://localhost:13133
    echo ""
    docker-compose ps --services --filter "status=running"

# Open Bifrost UI (macOS)
ui:
    open http://localhost:8080

# OpenClickHouse UI (macOS)
ch-ui:
    open http://localhost:8123/play

# ── Gentle-AI (Spec-Driven Development) ─────────────

# Install gentle-ai CLI via Homebrew
gentle-ai-install:
    brew tap Gentleman-Programming/homebrew-tap
    brew trust --formula gentleman-programming/tap/gentle-ai
    brew install gentle-ai

# Gentle-AI install — or use brew install gentle-ai first, then:
# go install github.com/gentleman-programming/gentle-ai/cmd/gentle-ai@latest

# Set up gentle-ai for this project (workspace-scoped so config stays local)
gentle-ai-setup:
    gentle-ai install --scope=workspace
    echo "✅ Gentle-AI configured for this project"
    echo "→ Run 'just gentle-ai-sdd-init' to initialize SDD context"

# Initialize SDD context (detects stack, testing, activates Strict TDD Mode)
gentle-ai-sdd-init:
    @echo "Run this command inside your AI agent:"
    @echo "  /sdd-init"
    @echo ""
    @echo "Or from CLI: gentle-ai skill-registry refresh"

# Refresh the skill registry (after installing/removing skills)
gentle-ai-skill-registry:
    gentle-ai skill-registry refresh

# Health check your gentle-ai ecosystem
gentle-ai-doctor:
    gentle-ai doctor

# Sync gentle-ai config and profiles
gentle-ai-sync profile="":
    gentle-ai sync {{profile}}

# Create an OpenCode SDD profile with per-phase models via Bifrost
# Usage: just gentle-ai-profile name="default" design="gpt-4o" implement="gpt-4o-mini" explore="gpt-4o-mini"
gentle-ai-profile name="default" design="gpt-4o" implement="gpt-4o-mini" explore="gpt-4o-mini":
    gentle-ai sync --profile {{name}}:github-models/{{design}}
    gentle-ai sync --profile-phase {{name}}:sdd-design:github-models/{{design}}
    gentle-ai sync --profile-phase {{name}}:sdd-implement:github-models/{{implement}}
    gentle-ai sync --profile-phase {{name}}:sdd-explore:github-models/{{explore}}
    echo "✅ SDD profile '{{name}}' created with Bifrost models"
    echo "→ Press Tab in OpenCode to switch profiles"

# ── First-Time Setup ────────────────────────────────

# First-time setup: start stack + init bifrost-cli config
setup:
    just up
    echo "Initializing bifrost-cli config..."
    just init-cli
    echo ""
    echo "✅ Stack is up at http://localhost:8080"

# ── OpenCode + Claude ────────────────────────────────

# Install the opencode-with-claude plugin globally
claude-plugin-install:
    npm install -g opencode-with-claude
    echo "✅ opencode-with-claude plugin installed"

# Authenticate with Claude Max (one-time OAuth login)
claude-login:
    npm install -g @anthropic-ai/claude-code
    claude login

# Check Claude authentication status
claude-status:
    claude auth status

# Start stack and launch OpenCode
opencode:
    just up
    echo "→ Stack is up"
    echo "→ Headroom proxy at http://localhost:8787 (compresses LLM traffic)"
    echo "→ Bifrost at http://localhost:8080"
    echo "→ Gentle-AI available (run 'just gentle-ai-doctor' to check)"
    echo "→ Launching OpenCode via bifrost-cli..."
    echo ""
    PATH="$HOME/.bifrost/bin:$PATH" bifrost

# Init bifrost-cli user config (~/.bifrost/)
init-cli:
    mkdir -p ~/.bifrost
    cp -n bifrost-cli-config.example.json ~/.bifrost/config.json 2>/dev/null && echo "Created ~/.bifrost/config.json" || echo "~/.bifrost/config.json already exists"
    cp -n bifrost-cli-state.example.json ~/.bifrost/state.json 2>/dev/null && echo "Created ~/.bifrost/state.json" || echo "~/.bifrost/state.json already exists"
    echo "Config ready at ~/.bifrost/"

# ── Headroom ────────────────────────────────────

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
headroom-test msg="Say hello in one word":
    curl -s -X POST http://localhost:8787/v1/chat/completions \
      -H "Content-Type: application/json" \
      -d '{"model":"gpt-4o-mini","messages":[{"role":"user","content":"{{msg}}"}]}' \
      | python3 -m json.tool

# Tail Headroom logs
headroom-logs:
    docker-compose logs --tail=50 -f headroom

# Install headroom-ai Python package locally (for MCP, proxy CLI, or library use)
headroom-install-python:
    pip install "headroom-ai[proxy,mcp]"
