#!/bin/bash
set -e

echo " ProStaff API - Starting..."

# Remove any pre-existing server PID file
rm -f /app/tmp/pids/server.pid

# Wait for database to be ready
echo "⏳ Waiting for database..."
until PGPASSWORD=$POSTGRES_PASSWORD psql -h postgres -U $POSTGRES_USER -d $POSTGRES_DB -c '\q' 2>/dev/null; do
  echo "  Database is unavailable - sleeping"
  sleep 2
done
echo "✅ Database is ready"

# Run database migrations
echo " Running database migrations..."
bundle exec rails db:migrate 2>/dev/null || {
  echo "⚠️  Migration failed, attempting to create database..."
  bundle exec rails db:create
  bundle exec rails db:migrate
}

# Preload app for better performance
if [ "$RAILS_ENV" = "production" ]; then
  echo " Preloading application..."
  bundle exec rails runner 'Rails.application.eager_load!'
fi

echo "✅ Application ready!"

# Execute the main command
exec "$@"
