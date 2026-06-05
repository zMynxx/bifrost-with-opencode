# ─────────────────────────────────────────────────────
# Bifrost + OpenTelemetry + ClickHouse + Ollama
# ─────────────────────────────────────────────────────

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

# ── Model Management ─────────────────────────────────

# Pull a new model into Ollama (usage: just pull MODEL)
pull model="qwen2.5-coder:1.5b":
    docker-compose exec ollama ollama pull {{model}}

# List models available through Bifrost
models:
    curl -s http://localhost:8080/v1/models | python3 -m json.tool

# List models in Ollama directly
ollama-models:
    docker-compose exec ollama ollama list

# ── Testing ──────────────────────────────────────────

# Send a test chat completion
test msg="Say hello in one word":
    curl -s -X POST http://localhost:8080/v1/chat/completions \
      -H "Content-Type: application/json" \
      -d '{"model":"ollama/qwen2.5-coder:1.5b","messages":[{"role":"user","content":"{{msg}}"}]}' \
      | python3 -m json.tool

# Test through the OpenAI-compatible endpoint
test-openai msg="Say hello in one word":
    curl -s -X POST http://localhost:8080/openai/chat/completions \
      -H "Content-Type: application/json" \
      -d '{"model":"ollama/qwen2.5-coder:1.5b","messages":[{"role":"user","content":"{{msg}}"}]}' \
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
    echo "=== Ollama ==="
    curl -s -o /dev/null -w "HTTP %{http_code}\n" http://localhost:11434
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

# ── First-Time Setup ────────────────────────────────

# Full first-time setup: start stack, pull model, init bifrost-cli
setup model="qwen2.5-coder:1.5b":
    just up
    echo "Pulling {{model}}..."
    docker-compose exec -T ollama ollama pull {{model}}
    echo "Initializing bifrost-cli config..."
    just init-cli
    echo ""
    echo "✅ Stack is up at http://localhost:8080"
    echo "✅ Model {{model}} is ready"
    echo "✅ bifrost-cli configured — run 'bifrost' to start"
    just test

# Init bifrost-cli user config (~/.bifrost/)
init-cli:
    mkdir -p ~/.bifrost
    cp -n bifrost-cli-config.example.json ~/.bifrost/config.json 2>/dev/null && echo "Created ~/.bifrost/config.json" || echo "~/.bifrost/config.json already exists"
    cp -n bifrost-cli-state.example.json ~/.bifrost/state.json 2>/dev/null && echo "Created ~/.bifrost/state.json" || echo "~/.bifrost/state.json already exists"
    echo "Config ready at ~/.bifrost/"

# ── Supported Models ─────────────────────────────────
# qwen2.5-coder:1.5b  — ~986MB, 32K context, Q4_K_M
# Pull more via: just pull <model>
# Popular options:
#   qwen2.5-coder:7b      — ~4.7GB, stronger coding
#   llama3.2:3b           — ~2.0GB, general purpose
#   mistral:7b            — ~4.1GB, fast general
#   tinyllama:latest      — ~637MB, very fast, small
