#!/bin/bash
# Decidim Backup Script
# Backups PostgreSQL DB and uploads folder

# Load environment variables
source .env

# Backup directory
BACKUP_DIR="./backups/$(date +%Y-%m-%d)"
mkdir -p "$BACKUP_DIR"

echo "Starting Decidim backup..."

# Backup PostgreSQL
docker exec decidim-db pg_dump -U decidim decidim > "$BACKUP_DIR/decidim_db.sql"
echo "Database backup saved to $BACKUP_DIR/decidim_db.sql"

# Backup uploads
cp -r ./uploads "$BACKUP_DIR/uploads"
echo "Uploads backup saved to $BACKUP_DIR/uploads"

echo "Backup completed successfully."
