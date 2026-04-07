#!/bin/bash
SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
COMPOSE_FILE="$SCRIPT_DIR/docker/docker-compose.yml"

echo "[INFO] Bringing down all services..."
docker compose -f "$COMPOSE_FILE" down

echo "[INFO] Starting all services..."
docker compose -f "$COMPOSE_FILE" up -d

echo "[INFO] Waiting for services to be ready..."
sleep 5

echo "[INFO] Service status:"
docker compose -f "$COMPOSE_FILE" ps

echo "[INFO] Recent API logs:"
docker compose -f "$COMPOSE_FILE" logs api --tail 20

read -p "Press Enter to close..."
