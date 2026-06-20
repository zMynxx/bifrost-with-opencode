# ── OpenTelemetry Observability ────────────────

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
