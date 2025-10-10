#!/bin/bash
# ProStaff API - Rollback Script
# Usage: ./deploy/scripts/rollback.sh [staging|production]

set -e

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m'

ENVIRONMENT="${1:-staging}"
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "$SCRIPT_DIR/../.." && pwd)"

echo -e "${YELLOW}=================================${NC}"
echo -e "${YELLOW}ProStaff API Rollback${NC}"
echo -e "${YELLOW}=================================${NC}"
echo "Environment: $ENVIRONMENT"
echo ""

# Validate environment
if [[ "$ENVIRONMENT" != "staging" ]] && [[ "$ENVIRONMENT" != "production" ]]; then
    echo -e "${RED}❌ Invalid environment: $ENVIRONMENT${NC}"
    exit 1
fi

# Confirmation
echo -e "${RED}⚠️  WARNING: This will rollback to the previous version${NC}"
read -p "Are you sure you want to continue? (yes/no): " CONFIRM
if [[ "$CONFIRM" != "yes" ]]; then
    echo "Rollback cancelled."
    exit 0
fi

cd "$PROJECT_ROOT"

# Check for rollback version file
if [ ! -f .rollback_version ]; then
    echo -e "${YELLOW}⚠️  No rollback version found${NC}"
    echo "Showing recent git tags..."
    git tag --sort=-version:refname | head -10
    read -p "Enter version to rollback to (e.g., v1.0.0): " VERSION
    if [ -z "$VERSION" ]; then
        echo "No version specified. Exiting."
        exit 1
    fi
else
    VERSION=$(cat .rollback_version)
    echo "Found rollback version: $VERSION"
fi

# Backup current database before rollback
echo ""
echo "💾 Creating backup before rollback..."
docker-compose -f docker-compose.production.yml run --rm backup || {
    echo -e "${YELLOW}⚠️  Backup failed${NC}"
    read -p "Continue anyway? (yes/no): " CONTINUE
    if [[ "$CONTINUE" != "yes" ]]; then
        exit 1
    fi
}

# Checkout previous version
echo ""
echo "📥 Checking out version: $VERSION"
git fetch --all --tags
git checkout "$VERSION"

# Rebuild and restart services
echo ""
echo "🔨 Rebuilding images..."
docker-compose -f docker-compose.production.yml build

echo ""
echo "🔄 Restarting services..."
docker-compose -f docker-compose.production.yml down
docker-compose -f docker-compose.production.yml up -d

# Wait for services
echo ""
echo "⏳ Waiting for services..."
sleep 15

# Health check
echo ""
echo "🏥 Running health check..."
MAX_ATTEMPTS=20
ATTEMPT=0

while [ $ATTEMPT -lt $MAX_ATTEMPTS ]; do
    if docker-compose -f docker-compose.production.yml exec -T api curl -f http://localhost:3000/up > /dev/null 2>&1; then
        echo -e "${GREEN}✅ Services are healthy${NC}"
        break
    fi

    ATTEMPT=$((ATTEMPT + 1))
    echo "Attempt $ATTEMPT/$MAX_ATTEMPTS..."
    sleep 3

    if [ $ATTEMPT -eq $MAX_ATTEMPTS ]; then
        echo -e "${RED}❌ Health check failed${NC}"
        echo "Showing logs..."
        docker-compose -f docker-compose.production.yml logs --tail=50 api
        exit 1
    fi
done

# Check if database needs rollback
echo ""
read -p "Do you need to rollback database? (yes/no): " ROLLBACK_DB
if [[ "$ROLLBACK_DB" == "yes" ]]; then
    echo "Available backups:"
    ls -lh backups/*.sql.gz | tail -10
    echo ""
    read -p "Enter backup filename: " BACKUP_FILE

    if [ -f "backups/$BACKUP_FILE" ]; then
        echo "Restoring database from: $BACKUP_FILE"
        gunzip < "backups/$BACKUP_FILE" | \
        docker-compose -f docker-compose.production.yml exec -T postgres \
        psql -U "$POSTGRES_USER" -d "$POSTGRES_DB"

        echo "Running migrations..."
        docker-compose -f docker-compose.production.yml exec -T api bundle exec rails db:migrate
    else
        echo -e "${RED}❌ Backup file not found${NC}"
    fi
fi

# Final verification
echo ""
echo " Service status:"
docker-compose -f docker-compose.production.yml ps

echo ""
echo -e "${GREEN}=================================${NC}"
echo -e "${GREEN}✅ Rollback completed${NC}"
echo -e "${GREEN}=================================${NC}"
echo "Version: $VERSION"
echo "Time: $(date)"
echo ""
