# ── Diagnostics ───────────────────────────────

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

# Open ClickHouse UI (macOS)
ch-ui:
    open http://localhost:8123/play
