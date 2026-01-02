#!/bin/bash
# ============================================================================
# Greengrass Edge Database Setup Script
# Version: 1.0.0
# Purpose: Deploy SQLite database schema to Greengrass device
# ============================================================================

set -e  # Exit on error

# Configuration
DB_DIR="/var/greengrass/database"
DB_FILE="$DB_DIR/greengrass.db"
SCHEMA_FILE="$(dirname "$0")/../database/schema.sql"
BACKUP_DIR="$DB_DIR/backups"
GG_USER="${GREENGRASS_USER:-ggc_user}"
GG_GROUP="${GREENGRASS_GROUP:-ggc_group}"

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

# Logging functions
log_info() {
    echo -e "${GREEN}[INFO]${NC} $1"
}

log_warn() {
    echo -e "${YELLOW}[WARN]${NC} $1"
}

log_error() {
    echo -e "${RED}[ERROR]${NC} $1"
}

# Check if running as sudo
if [ "$EUID" -ne 0 ]; then
    log_error "Please run with sudo"
    exit 1
fi

log_info "Starting Greengrass Edge Database Setup..."
log_info "Database path: $DB_FILE"

# Step 1: Create database directory
log_info "Creating database directory..."
mkdir -p "$DB_DIR"
mkdir -p "$BACKUP_DIR"

# Set directory permissions immediately
chown -R "$GG_USER:$GG_GROUP" "$DB_DIR"
chmod 775 "$DB_DIR"

# Step 2: Backup existing database if it exists
if [ -f "$DB_FILE" ]; then
    BACKUP_FILE="$BACKUP_DIR/greengrass-$(date +%Y%m%d-%H%M%S).db"
    log_warn "Existing database found. Creating backup: $BACKUP_FILE"
    cp "$DB_FILE" "$BACKUP_FILE"
fi

# Step 3: Verify schema file exists
if [ ! -f "$SCHEMA_FILE" ]; then
    log_error "Schema file not found: $SCHEMA_FILE"
    exit 1
fi

log_info "Schema file found: $SCHEMA_FILE"

# Step 3.5: Ensure schema file is readable by ggc_user
chmod 644 "$SCHEMA_FILE"
chown "$GG_USER:$GG_GROUP" "$SCHEMA_FILE"

# Step 4: Apply database schema
log_info "Applying database schema..."
if sudo -u "$GG_USER" sqlite3 "$DB_FILE" < "$SCHEMA_FILE"; then
    log_info "✅ Database schema applied successfully"
else
    log_error "Failed to apply database schema"
    exit 1
fi

# Step 5: Verify database
log_info "Verifying database..."
TABLE_COUNT=$(sudo -u "$GG_USER" sqlite3 "$DB_FILE" "SELECT COUNT(*) FROM sqlite_master WHERE type='table';")
VIEW_COUNT=$(sudo -u "$GG_USER" sqlite3 "$DB_FILE" "SELECT COUNT(*) FROM sqlite_master WHERE type='view';")
INDEX_COUNT=$(sudo -u "$GG_USER" sqlite3 "$DB_FILE" "SELECT COUNT(*) FROM sqlite_master WHERE type='index';")

log_info "Database verification:"
log_info "  - Tables: $TABLE_COUNT"
log_info "  - Views: $VIEW_COUNT"
log_info "  - Indexes: $INDEX_COUNT"

# Step 6: Check schema version
SCHEMA_VERSION=$(sudo -u "$GG_USER" sqlite3 "$DB_FILE" "SELECT schema_version FROM _metadata LIMIT 1;")
log_info "  - Schema Version: $SCHEMA_VERSION"

# Step 7: Set proper permissions
log_info "Setting file permissions..."
chmod 660 "$DB_FILE"
chown "$GG_USER:$GG_GROUP" "$DB_FILE"
chown -R "$GG_USER:$GG_GROUP" "$DB_DIR"

# Step 8: Verify configuration table
log_info "Checking default configuration..."
CONFIG_COUNT=$(sudo -u "$GG_USER" sqlite3 "$DB_FILE" "SELECT COUNT(*) FROM configuration;")
log_info "  - Configuration entries: $CONFIG_COUNT"

# Step 9: Display database info
log_info "Database information:"
DB_SIZE=$(du -h "$DB_FILE" | cut -f1)
log_info "  - Size: $DB_SIZE"
log_info "  - Owner: $(stat -c '%U:%G' "$DB_FILE")"
log_info "  - Permissions: $(stat -c '%a' "$DB_FILE")"

log_info "✅ Database setup completed successfully!"
log_info ""
log_info "Database location: $DB_FILE"
log_info "To verify, run: sudo -u $GG_USER sqlite3 $DB_FILE '.schema'"

exit 0
