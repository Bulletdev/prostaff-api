#!/bin/bash
# ProStaff API - Database Backup Script

set -e

BACKUP_DIR="/backups"
TIMESTAMP=$(date +"%Y%m%d_%H%M%S")
BACKUP_FILE="$BACKUP_DIR/prostaff_${POSTGRES_DB}_${TIMESTAMP}.sql.gz"
RETENTION_DAYS=${BACKUP_RETENTION_DAYS:-30}

echo "🔄 Starting database backup..."
echo "  Database: $PGDATABASE"
echo "  Timestamp: $TIMESTAMP"

# Create backup directory if it doesn't exist
mkdir -p "$BACKUP_DIR"

# Perform backup
pg_dump --no-owner --no-acl --clean --if-exists | gzip > "$BACKUP_FILE"

# Verify backup
if [ -f "$BACKUP_FILE" ]; then
  SIZE=$(du -h "$BACKUP_FILE" | cut -f1)
  echo "✅ Backup completed successfully"
  echo "  File: $BACKUP_FILE"
  echo "  Size: $SIZE"
else
  echo "❌ Backup failed!"
  exit 1
fi

# Clean old backups
echo "🗑️  Cleaning backups older than $RETENTION_DAYS days..."
find "$BACKUP_DIR" -name "prostaff_*.sql.gz" -type f -mtime +$RETENTION_DAYS -delete
REMAINING=$(find "$BACKUP_DIR" -name "prostaff_*.sql.gz" -type f | wc -l)
echo "  Remaining backups: $REMAINING"

# Upload to S3 (if AWS credentials are configured)
if [ -n "$AWS_ACCESS_KEY_ID" ] && [ -n "$BACKUP_S3_BUCKET" ]; then
  echo "☁️  Uploading to S3..."
  aws s3 cp "$BACKUP_FILE" "s3://$BACKUP_S3_BUCKET/database-backups/" || {
    echo "⚠️  S3 upload failed, backup saved locally only"
  }
fi

echo "✅ Backup process completed"
