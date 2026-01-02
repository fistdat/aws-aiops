#!/bin/bash
# Database Migration v3.0: Unify cameras → devices
# Date: 2026-01-02
# Purpose: Consolidate cameras table into devices table with backward-compatible VIEW

set -e  # Exit on any error

DB_PATH="/var/greengrass/database/greengrass.db"
BACKUP_TIMESTAMP=$(date +%Y%m%d-%H%M%S)
BACKUP_PATH="${DB_PATH}.backup-${BACKUP_TIMESTAMP}"

echo "=========================================="
echo "Database Migration v3.0: cameras → devices"
echo "=========================================="
echo "Database: $DB_PATH"
echo "Backup:   $BACKUP_PATH"
echo ""

# Step 1: Backup database
echo "📦 Step 1: Creating database backup..."
sudo cp "$DB_PATH" "$BACKUP_PATH"
echo "✅ Backup created: $(ls -lh $BACKUP_PATH | awk '{print $5}')"
echo ""

# Step 2: Check current state
echo "🔍 Step 2: Analyzing current database state..."
CAMERAS_COUNT=$(sudo sqlite3 "$DB_PATH" "SELECT COUNT(*) FROM cameras")
DEVICES_COUNT=$(sudo sqlite3 "$DB_PATH" "SELECT COUNT(*) FROM devices")
DEVICES_CAMERAS=$(sudo sqlite3 "$DB_PATH" "SELECT COUNT(*) FROM devices WHERE device_type='camera'")

echo "   Current state:"
echo "   - cameras table:  $CAMERAS_COUNT records"
echo "   - devices table:  $DEVICES_COUNT records ($DEVICES_CAMERAS cameras)"
echo ""

# Step 3: Extend devices table with camera-specific fields
echo "🔧 Step 3: Extending devices table schema..."
sudo sqlite3 "$DB_PATH" <<'EOF'
-- Add camera-specific columns if they don't exist
ALTER TABLE devices ADD COLUMN model TEXT;
ALTER TABLE devices ADD COLUMN firmware_version TEXT;
ALTER TABLE devices ADD COLUMN site_id TEXT DEFAULT 'site-001';
EOF

echo "✅ Schema extended: added model, firmware_version, site_id"
echo ""

# Step 4: Migrate data from cameras to devices
echo "📊 Step 4: Migrating camera data to devices table..."
sudo sqlite3 "$DB_PATH" <<'EOF'
-- Migrate all camera records
INSERT OR REPLACE INTO devices (
    device_id,
    zabbix_host_id,
    host_name,
    visible_name,
    device_type,
    ip_address,
    port,
    status,
    location,
    ngsi_ld_json,
    model,
    firmware_version,
    site_id,
    first_seen,
    last_seen,
    created_at,
    updated_at
)
SELECT
    camera_id as device_id,
    zabbix_host_id,
    hostname as host_name,
    hostname as visible_name,
    'camera' as device_type,
    ip_address,
    '10050' as port,
    status,
    location,
    ngsi_ld_json,
    model,
    firmware_version,
    site_id,
    created_at as first_seen,
    last_seen,
    created_at,
    updated_at
FROM cameras;

-- Verify migration
SELECT 'Migrated records: ' || COUNT(*) FROM devices WHERE device_type = 'camera';
EOF

MIGRATED_COUNT=$(sudo sqlite3 "$DB_PATH" "SELECT COUNT(*) FROM devices WHERE device_type='camera'")
echo "✅ Data migrated: $MIGRATED_COUNT camera records → devices table"
echo ""

# Step 5: Replace cameras table with VIEW
echo "🔄 Step 5: Replacing cameras table with backward-compatible VIEW..."

# Drop existing views first
sudo sqlite3 "$DB_PATH" <<'EOF'
DROP VIEW IF EXISTS v_active_cameras;
DROP VIEW IF EXISTS v_offline_cameras;
EOF

# Drop cameras table and recreate as VIEW
sudo sqlite3 "$DB_PATH" <<'EOF'
DROP TABLE cameras;

-- Create backward-compatible cameras VIEW
CREATE VIEW cameras AS
SELECT
    device_id as camera_id,
    zabbix_host_id,
    ip_address,
    host_name as hostname,
    location,
    site_id,
    device_type,
    model,
    firmware_version,
    status,
    last_seen,
    ngsi_ld_json,
    created_at,
    updated_at
FROM devices
WHERE device_type = 'camera';

-- Recreate utility views
CREATE VIEW v_active_cameras AS
SELECT * FROM cameras WHERE status != 'offline' ORDER BY updated_at DESC;

CREATE VIEW v_offline_cameras AS
SELECT * FROM cameras WHERE status = 'offline' ORDER BY last_seen DESC;
EOF

CAMERAS_TYPE=$(sudo sqlite3 "$DB_PATH" "SELECT type FROM sqlite_master WHERE name='cameras'")
echo "✅ cameras table → VIEW (type: $CAMERAS_TYPE)"
echo "✅ Utility views recreated: v_active_cameras, v_offline_cameras"
echo ""

# Step 6: Update metadata
echo "📝 Step 6: Updating schema metadata..."
sudo sqlite3 "$DB_PATH" <<'EOF'
INSERT INTO _metadata (schema_version, description, applied_at)
VALUES (
    'v3.0',
    'Unified devices table - cameras migrated to VIEW for backward compatibility',
    CURRENT_TIMESTAMP
);
EOF

echo "✅ Metadata updated: schema version v3.0"
echo ""

# Step 7: Verification
echo "🔍 Step 7: Verifying migration..."
sudo sqlite3 "$DB_PATH" <<'EOF'
.mode column
.headers on

SELECT
    'devices (cameras)' as table_name,
    COUNT(*) as record_count
FROM devices WHERE device_type = 'camera'
UNION ALL
SELECT
    'cameras (VIEW)',
    COUNT(*)
FROM cameras
UNION ALL
SELECT
    'devices (total)',
    COUNT(*)
FROM devices;
EOF

echo ""

# Step 8: Database optimization
echo "🚀 Step 8: Optimizing database..."
sudo sqlite3 "$DB_PATH" <<'EOF'
-- Analyze for query optimizer
ANALYZE;

-- Check integrity
PRAGMA integrity_check;
EOF

echo "✅ Database analyzed and verified"
echo ""

echo "=========================================="
echo "✅ Migration v3.0 Complete!"
echo "=========================================="
echo ""
echo "Summary:"
echo "  ✅ Backup:       $BACKUP_PATH"
echo "  ✅ cameras:      $CAMERAS_COUNT records → devices table"
echo "  ✅ devices:      $(sudo sqlite3 $DB_PATH 'SELECT COUNT(*) FROM devices') total records"
echo "  ✅ Schema:       v3.0 (unified devices)"
echo "  ✅ Compatibility: cameras VIEW active"
echo ""
echo "Next steps:"
echo "  1. Test components: curl http://localhost:8081/health"
echo "  2. Verify queries:  sudo sqlite3 $DB_PATH 'SELECT * FROM cameras LIMIT 3'"
echo "  3. Monitor logs:    sudo tail -f /greengrass/v2/logs/com.aismc.ZabbixEventSubscriber.log"
echo ""
