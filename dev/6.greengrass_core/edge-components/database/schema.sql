-- ============================================================================
-- Database Schema Migration v3.0: Unified Devices Architecture
-- Purpose: Consolidate cameras table into devices table with backward-compatible VIEW
-- Date: 2026-01-02
-- Migration Strategy: cameras TABLE → cameras VIEW + extended devices table
-- ============================================================================

-- Enable WAL mode and foreign keys
PRAGMA journal_mode = WAL;
PRAGMA foreign_keys = ON;
PRAGMA synchronous = NORMAL;

-- ============================================================================
-- STEP 1: Extend devices table with camera-specific fields
-- ============================================================================

-- Add camera-specific columns (if they don't exist)
ALTER TABLE devices ADD COLUMN model TEXT;
ALTER TABLE devices ADD COLUMN firmware_version TEXT;
ALTER TABLE devices ADD COLUMN site_id TEXT DEFAULT 'site-001';

-- ============================================================================
-- STEP 2: Migrate all cameras data to devices table
-- ============================================================================

-- Migrate existing camera records from cameras table to devices table
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
FROM cameras
WHERE EXISTS (SELECT 1 FROM sqlite_master WHERE type='table' AND name='cameras');

-- ============================================================================
-- STEP 3: Drop existing camera-related views
-- ============================================================================

DROP VIEW IF EXISTS v_active_cameras;
DROP VIEW IF EXISTS v_offline_cameras;

-- ============================================================================
-- STEP 4: Replace cameras table with backward-compatible VIEW
-- ============================================================================

-- Drop cameras TABLE (all data is now in devices)
DROP TABLE IF EXISTS cameras;

-- Create cameras VIEW for 100% backward compatibility
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

-- ============================================================================
-- STEP 5: Recreate utility views (using new cameras VIEW)
-- ============================================================================

-- Active cameras (not offline)
CREATE VIEW v_active_cameras AS
SELECT * FROM cameras WHERE status != 'offline' ORDER BY updated_at DESC;

-- Offline cameras
CREATE VIEW v_offline_cameras AS
SELECT * FROM cameras WHERE status = 'offline' ORDER BY last_seen DESC;

-- ============================================================================
-- STEP 6: Update database metadata
-- ============================================================================

-- Update schema version
INSERT OR REPLACE INTO _metadata (schema_version, description, applied_at)
VALUES (
    '3.0.0',
    'Unified devices table - cameras migrated to VIEW for backward compatibility',
    CURRENT_TIMESTAMP
);

-- Update database version in configuration
UPDATE configuration
SET value = '3.0.0', updated_at = CURRENT_TIMESTAMP
WHERE key = 'database_version';

-- ============================================================================
-- STEP 7: Optimize database
-- ============================================================================

-- Analyze tables for query optimizer
ANALYZE;

-- Verify integrity
PRAGMA integrity_check;

-- ============================================================================
-- Verification Queries
-- ============================================================================

-- Check that cameras is now a VIEW
SELECT
    'cameras object type:' as check_name,
    type as result
FROM sqlite_master
WHERE name = 'cameras';
-- Expected: view

-- Count cameras in both VIEW and devices table
SELECT 'cameras VIEW count:' as check_name, COUNT(*) as result FROM cameras
UNION ALL
SELECT 'devices (camera) count:', COUNT(*) FROM devices WHERE device_type='camera';
-- Expected: same count

-- Verify all camera fields are accessible via VIEW
SELECT
    'Sample camera from VIEW:' as check_name,
    camera_id, hostname, status, model, firmware_version
FROM cameras
LIMIT 1;

-- Check schema version
SELECT
    'Schema version:' as check_name,
    schema_version as result
FROM _metadata
ORDER BY applied_at DESC
LIMIT 1;
-- Expected: 3.0.0

-- ============================================================================
-- Migration Summary
-- ============================================================================

SELECT '=== Migration v3.0 Summary ===' as info;

SELECT
    'Total devices' as metric,
    COUNT(*) as value
FROM devices
UNION ALL
SELECT
    'Cameras (device_type=camera)',
    COUNT(*)
FROM devices
WHERE device_type = 'camera'
UNION ALL
SELECT
    'Cameras (VIEW)',
    COUNT(*)
FROM cameras
UNION ALL
SELECT
    'Other devices',
    COUNT(*)
FROM devices
WHERE device_type != 'camera';

-- ============================================================================
-- Rollback Instructions (if needed)
-- ============================================================================
-- If migration fails or needs rollback, restore from backup:
--
-- 1. Stop Greengrass:
--    sudo systemctl stop greengrass
--
-- 2. Restore backup:
--    sudo cp /var/greengrass/database/greengrass.db.backup-YYYYMMDD-HHMMSS \
--            /var/greengrass/database/greengrass.db
--
-- 3. Start Greengrass:
--    sudo systemctl start greengrass
--
-- ============================================================================
