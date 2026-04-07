#!/bin/bash
SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
COMPOSE_FILE="$SCRIPT_DIR/docker/docker-compose.yml"

echo "[INFO] Restarting API and Sidekiq containers (reloading env vars)..."
docker compose -f "$COMPOSE_FILE" up -d --force-recreate api sidekiq

echo "[INFO] Waiting for services to be ready..."
sleep 3

echo "[INFO] Recent logs (api):"
docker logs prostaff-api --tail 10

echo "[INFO] Recent logs (sidekiq):"
docker logs docker-sidekiq-1 --tail 10

read -p "Press Enter to close..."
