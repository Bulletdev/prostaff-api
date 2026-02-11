#!/bin/bash
set -e

echo "========================================" >&2
echo "ProStaff API - Docker Entrypoint" >&2
echo "========================================" >&2

# Remove any pre-existing server PID file
echo "[1/4] Removing stale PID files..." >&2
rm -f /app/tmp/pids/server.pid

# Wait for database to be ready
echo "[2/4] Checking database connection..." >&2
DB_URL="${SUPABASE_DB_URL:-$DATABASE_URL}"
if [ -n "$DB_URL" ]; then
  # Extract host and port from URL (format: postgresql://user:pass@host:port/db)
  # Parse from right to left to handle @ in password
  DB_HOST=$(echo "$DB_URL" | sed -E 's|.*@([^@/]+):[0-9]+/.*|\1|')
  DB_PORT=$(echo "$DB_URL" | sed -E 's|.*@[^@/]+:([0-9]+)/.*|\1|')

  echo "  → Host: ${DB_HOST}:${DB_PORT}" >&2

  MAX_RETRIES=30
  RETRY_COUNT=0
  until pg_isready -h "$DB_HOST" -p "$DB_PORT" > /dev/null 2>&1; do
    RETRY_COUNT=$((RETRY_COUNT + 1))
    if [ $RETRY_COUNT -ge $MAX_RETRIES ]; then
      echo "  ✗ Database connection timeout after ${MAX_RETRIES} attempts" >&2
      exit 1
    fi
    echo "  ⏳ Waiting for database (attempt ${RETRY_COUNT}/${MAX_RETRIES})..." >&2
    sleep 2
  done
  echo "  ✓ Database is ready" >&2
else
  echo "  ⚠ No DATABASE_URL configured, skipping database check" >&2
fi

# Run database migrations
echo "[3/4] Running database migrations..." >&2
if bundle exec rails db:migrate 2>&1 | tee /tmp/migration.log >&2; then
  echo "  ✓ Migrations completed" >&2
else
  echo "  ⚠ Migration failed, check output above" >&2
  echo "  → Attempting to create database..." >&2
  bundle exec rails db:create 2>&1 | tee -a /tmp/migration.log >&2
  bundle exec rails db:migrate 2>&1 | tee -a /tmp/migration.log >&2
fi

# Skip preload in production - Puma will handle it
echo "[4/4] Starting application server..." >&2
echo "  → Port: ${PORT:-3000}" >&2
echo "  → Environment: ${RAILS_ENV:-development}" >&2
echo "  → Workers: ${WEB_CONCURRENCY:-2}" >&2
echo "========================================" >&2

# Execute the main command
exec "$@"
