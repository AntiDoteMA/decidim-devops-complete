#!/bin/bash
# Decidim Restore Script
# Restores PostgreSQL DB and uploads folder from backup

# Load environment variables
source .env

BACKUP_PATH=$1

if [ -z "$BACKUP_PATH" ]; then
  echo "Usage: ./restore.sh <backup_path>"
  exit 1
fi

echo "Restoring Decidim from $BACKUP_PATH..."

# Restore PostgreSQL
docker exec -i decidim-db psql -U decidim decidim < "$BACKUP_PATH/decidim_db.sql"
echo "Database restored from $BACKUP_PATH/decidim_db.sql"

# Restore uploads
rm -rf ./uploads
cp -r "$BACKUP_PATH/uploads" ./uploads
echo "Uploads restored from $BACKUP_PATH/uploads"

echo "Restore completed successfully."
