#!/bin/bash
set -e

echo " ProStaff API - Starting..."

# Skip DATABASE_URL encoding - handled by Rails initializer
# The initializer (config/initializers/database_url_override.rb) will detect
# special characters and parse manually in database.yml
echo " Database configuration will be handled by Rails initializer"

# Remove any pre-existing server PID file
rm -f /app/tmp/pids/server.pid

# Wait for database to be ready
echo " Waiting for database..."
# Use SUPABASE_DB_URL or DATABASE_URL, extract host for pg_isready
DB_URL="${SUPABASE_DB_URL:-$DATABASE_URL}"
if [ -n "$DB_URL" ]; then
  # Extract host and port from URL (format: postgresql://user:pass@host:port/db)
  # Parse from right to left to handle @ in password
  DB_HOST=$(echo "$DB_URL" | sed -E 's|.*@([^@/]+):[0-9]+/.*|\1|')
  DB_PORT=$(echo "$DB_URL" | sed -E 's|.*@[^@/]+:([0-9]+)/.*|\1|')

  echo "  Checking connection to ${DB_HOST}:${DB_PORT}..."
  until pg_isready -h "$DB_HOST" -p "$DB_PORT" > /dev/null 2>&1; do
    echo "  Database is unavailable - sleeping"
    sleep 2
  done
else
  until PGPASSWORD=$POSTGRES_PASSWORD psql -h "${POSTGRES_HOST:-postgres}" -U "$POSTGRES_USER" -d "$POSTGRES_DB" -c '\q' 2>/dev/null; do
    echo "  Database is unavailable - sleeping"
    sleep 2
  done
fi
echo " Database is ready"

# Run database migrations
echo " Running database migrations..."
bundle exec rails db:migrate 2>/dev/null || {
  echo "  Migration failed, attempting to create database..."
  bundle exec rails db:create
  bundle exec rails db:migrate
}

# Preload app for better performance
if [ "$RAILS_ENV" = "production" ]; then
  echo " Preloading application..."
  bundle exec rails runner 'Rails.application.eager_load!'
fi

echo " Application ready!"

echo " Starting application server..."

# Execute the main command
exec "$@"
