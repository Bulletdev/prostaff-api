#!/bin/bash
set -e

echo " ProStaff API - Starting..."

# Fix DATABASE_URL if it has unescaped special characters in password
if [ -n "$DATABASE_URL" ]; then
  # Extract components using parameter expansion
  if [[ "$DATABASE_URL" =~ ^postgresql://([^:]+):([^@]+)@(.+)$ ]]; then
    user="${BASH_REMATCH[1]}"
    pass="${BASH_REMATCH[2]}"
    rest="${BASH_REMATCH[3]}"

    # URL-encode the password using Python (available in our image)
    encoded_pass=$(python3 -c "import urllib.parse; print(urllib.parse.quote('$pass', safe=''))")

    # Reconstruct DATABASE_URL with encoded password
    export DATABASE_URL="postgresql://${user}:${encoded_pass}@${rest}"
    echo " DATABASE_URL password component URL-encoded"
  fi
fi

# Remove any pre-existing server PID file
rm -f /app/tmp/pids/server.pid

# Wait for database to be ready
echo " Waiting for database..."
if [ -n "$DATABASE_URL" ]; then
  until pg_isready -d "$DATABASE_URL"; do
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

# Execute the main command
exec "$@"
