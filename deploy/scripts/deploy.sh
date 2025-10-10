#!/bin/bash
# ProStaff API - Manual Deployment Script
# Usage: ./deploy/scripts/deploy.sh [staging|production]

set -e

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

# Configuration
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "$SCRIPT_DIR/../.." && pwd)"
ENVIRONMENT="${1:-staging}"

echo -e "${GREEN}=================================${NC}"
echo -e "${GREEN}ProStaff API Deployment${NC}"
echo -e "${GREEN}=================================${NC}"
echo "Environment: $ENVIRONMENT"
echo "Project Root: $PROJECT_ROOT"
echo ""

# Validate environment
if [[ "$ENVIRONMENT" != "staging" ]] && [[ "$ENVIRONMENT" != "production" ]]; then
    echo -e "${RED}❌ Invalid environment: $ENVIRONMENT${NC}"
    echo "Usage: $0 [staging|production]"
    exit 1
fi

# Confirmation for production
if [[ "$ENVIRONMENT" == "production" ]]; then
    echo -e "${RED}⚠️  WARNING: You are about to deploy to PRODUCTION${NC}"
    read -p "Are you sure you want to continue? (yes/no): " CONFIRM
    if [[ "$CONFIRM" != "yes" ]]; then
        echo "Deployment cancelled."
        exit 0
    fi
fi

cd "$PROJECT_ROOT"

# Check if .env file exists
if [ ! -f .env ]; then
    echo -e "${YELLOW}⚠️  .env file not found${NC}"
    if [ -f ".env.${ENVIRONMENT}.example" ]; then
        echo "Copying .env.${ENVIRONMENT}.example to .env"
        cp ".env.${ENVIRONMENT}.example" .env
        echo -e "${RED}🔧 Please configure .env file before continuing${NC}"
        exit 1
    else
        echo -e "${RED}❌ No example .env file found${NC}"
        exit 1
    fi
fi

# Git operations
echo ""
echo "📥 Pulling latest changes..."
git fetch origin

if [[ "$ENVIRONMENT" == "staging" ]]; then
    BRANCH="develop"
else
    # For production, use current tag or branch
    BRANCH=$(git symbolic-ref -q --short HEAD || git describe --tags --exact-match 2>/dev/null || echo "master")
fi

echo "Checking out: $BRANCH"
git checkout "$BRANCH"
git pull origin "$BRANCH" || echo "Already up to date"

# Check for uncommitted changes
if [[ -n $(git status -s) ]]; then
    echo -e "${YELLOW}⚠️  You have uncommitted changes${NC}"
    git status -s
    read -p "Continue anyway? (yes/no): " CONTINUE
    if [[ "$CONTINUE" != "yes" ]]; then
        exit 0
    fi
fi

# Docker operations
echo ""
echo "🐳 Docker operations..."

# Check if Docker is running
if ! docker info > /dev/null 2>&1; then
    echo -e "${RED}❌ Docker is not running${NC}"
    exit 1
fi

# Backup database
echo ""
echo "💾 Creating database backup..."
docker-compose -f docker-compose.production.yml run --rm backup || {
    echo -e "${YELLOW}⚠️  Backup failed, continuing...${NC}"
}

# Build new images
echo ""
echo "🔨 Building Docker images..."
docker-compose -f docker-compose.production.yml build --no-cache

# Stop old containers gracefully
echo ""
echo " Stopping old containers..."
docker-compose -f docker-compose.production.yml down --remove-orphans

# Start new containers
echo ""
echo " Starting new containers..."
docker-compose -f docker-compose.production.yml up -d

# Wait for services to be ready
echo ""
echo "⏳ Waiting for services to be ready..."
sleep 10

# Check service health
echo ""
echo " Checking service health..."
MAX_ATTEMPTS=30
ATTEMPT=0

while [ $ATTEMPT -lt $MAX_ATTEMPTS ]; do
    if docker-compose -f docker-compose.production.yml exec -T api curl -f http://localhost:3000/up > /dev/null 2>&1; then
        echo -e "${GREEN}✅ API is healthy${NC}"
        break
    fi

    ATTEMPT=$((ATTEMPT + 1))
    echo "Attempt $ATTEMPT/$MAX_ATTEMPTS..."
    sleep 2

    if [ $ATTEMPT -eq $MAX_ATTEMPTS ]; then
        echo -e "${RED}❌ Health check failed after $MAX_ATTEMPTS attempts${NC}"
        echo "Checking logs..."
        docker-compose -f docker-compose.production.yml logs --tail=50 api
        exit 1
    fi
done

# Run database migrations
echo ""
echo "📊 Running database migrations..."
docker-compose -f docker-compose.production.yml exec -T api bundle exec rails db:migrate

# Restart services to pick up changes
echo ""
echo "🔄 Restarting services..."
docker-compose -f docker-compose.production.yml restart

# Final health check
echo ""
echo " Final health check..."
sleep 5

if docker-compose -f docker-compose.production.yml exec -T api curl -f http://localhost:3000/up > /dev/null 2>&1; then
    echo -e "${GREEN}✅ Deployment successful!${NC}"
else
    echo -e "${RED}❌ Final health check failed${NC}"
    exit 1
fi

# Show running containers
echo ""
echo " Running containers:"
docker-compose -f docker-compose.production.yml ps

# Show logs
echo ""
echo " Recent logs:"
docker-compose -f docker-compose.production.yml logs --tail=20

# Cleanup
echo ""
echo "🧹 Cleaning up old images..."
docker image prune -af --filter "until=48h"

echo ""
echo -e "${GREEN}=================================${NC}"
echo -e "${GREEN}✅ Deployment completed!${NC}"
echo -e "${GREEN}=================================${NC}"
echo "Environment: $ENVIRONMENT"
echo "Branch: $BRANCH"
echo "Time: $(date)"
echo ""
echo "Useful commands:"
echo "  View logs:    docker-compose -f docker-compose.production.yml logs -f"
echo "  Console:      docker-compose -f docker-compose.production.yml exec api bundle exec rails console"
echo "  Restart:      docker-compose -f docker-compose.production.yml restart"
echo "  Stop:         docker-compose -f docker-compose.production.yml down"
echo ""
