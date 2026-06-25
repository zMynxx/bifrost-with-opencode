# ── Docker Service Management ─────────────────

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
