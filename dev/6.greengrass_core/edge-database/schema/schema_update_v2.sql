-- ============================================================================
-- Database Schema Update v2
-- Purpose: Add devices and host_groups tables for Zabbix host registry sync
-- Status: SUPERSEDED by v3.0 (cameras table → VIEW migration)
-- Note: For new deployments, use schema.sql v3.0.0 instead
-- ============================================================================

-- Enable WAL mode (if not already enabled)
PRAGMA journal_mode = WAL;
PRAGMA foreign_keys = ON;

-- ============================================================================
-- Host Groups Table (Zabbix host groups metadata)
-- ============================================================================

CREATE TABLE IF NOT EXISTS host_groups (
    groupid TEXT PRIMARY KEY,
    name TEXT NOT NULL UNIQUE,
    description TEXT,
    internal INTEGER DEFAULT 0,  -- 0=user-created, 1=internal
    flags INTEGER DEFAULT 0,
    created_at DATETIME DEFAULT CURRENT_TIMESTAMP,
    updated_at DATETIME DEFAULT CURRENT_TIMESTAMP
);

CREATE INDEX IF NOT EXISTS idx_hostgroups_name ON host_groups(name);
CREATE INDEX IF NOT EXISTS idx_hostgroups_updated ON host_groups(updated_at);

-- ============================================================================
-- Devices Table (Generalized for ALL Zabbix hosts)
-- ============================================================================

CREATE TABLE IF NOT EXISTS devices (
    device_id TEXT PRIMARY KEY,
    zabbix_host_id TEXT UNIQUE NOT NULL,
    host_name TEXT NOT NULL,
    visible_name TEXT,
    device_type TEXT DEFAULT 'unknown',  -- camera, server, network, etc.
    ip_address TEXT,
    port TEXT DEFAULT '10050',
    status TEXT DEFAULT 'unknown',  -- online | offline | unknown | disabled

    -- Zabbix metadata
    available INTEGER DEFAULT 0,  -- 0=unknown, 1=available, 2=unavailable
    maintenance_status INTEGER DEFAULT 0,  -- 0=no maintenance, 1=in maintenance
    lastchange INTEGER,  -- Unix timestamp of last change

    -- Host group associations (comma-separated groupids)
    host_groups TEXT,

    -- Location and tags
    location TEXT,
    tags TEXT,  -- JSON array of tags

    -- NGSI-LD representation
    ngsi_ld_json TEXT NOT NULL,

    -- Timestamps
    first_seen DATETIME DEFAULT CURRENT_TIMESTAMP,
    last_seen DATETIME DEFAULT CURRENT_TIMESTAMP,
    created_at DATETIME DEFAULT CURRENT_TIMESTAMP,
    updated_at DATETIME DEFAULT CURRENT_TIMESTAMP,

    UNIQUE(ip_address, port)
);

CREATE INDEX IF NOT EXISTS idx_devices_zabbix_host ON devices(zabbix_host_id);
CREATE INDEX IF NOT EXISTS idx_devices_type ON devices(device_type);
CREATE INDEX IF NOT EXISTS idx_devices_status ON devices(status);
CREATE INDEX IF NOT EXISTS idx_devices_ip ON devices(ip_address);
CREATE INDEX IF NOT EXISTS idx_devices_updated ON devices(updated_at);
CREATE INDEX IF NOT EXISTS idx_devices_lastchange ON devices(lastchange);

-- ============================================================================
-- Update Configuration Table with Sync Settings
-- ============================================================================

INSERT OR IGNORE INTO configuration (key, value, description) VALUES
    ('sync_schedule', '0 2 * * *', 'Cron expression for host registry sync (daily at 2AM)'),
    ('sync_enabled', 'true', 'Enable/disable scheduled host registry sync'),
    ('last_sync_timestamp', '', 'ISO8601 timestamp of last successful host sync'),
    ('last_sync_unix', '0', 'Unix timestamp of last successful host sync for incremental queries'),
    ('incremental_sync', 'true', 'Enable incremental sync (only changed hosts)'),
    ('total_devices', '0', 'Total number of devices synced'),
    ('total_host_groups', '0', 'Total number of host groups synced'),
    ('zabbix_api_url', 'http://localhost:8080/api_jsonrpc.php', 'Zabbix API endpoint'),
    ('zabbix_username', 'Admin', 'Zabbix API username'),
    ('zabbix_password', 'zabbix', 'Zabbix API password (should use secure storage)');

-- ============================================================================
-- Trigger to Update Timestamps
-- ============================================================================

CREATE TRIGGER IF NOT EXISTS update_devices_timestamp
AFTER UPDATE ON devices
BEGIN
    UPDATE devices SET updated_at = CURRENT_TIMESTAMP WHERE device_id = NEW.device_id;
END;

CREATE TRIGGER IF NOT EXISTS update_hostgroups_timestamp
AFTER UPDATE ON host_groups
BEGIN
    UPDATE host_groups SET updated_at = CURRENT_TIMESTAMP WHERE groupid = NEW.groupid;
END;

-- ============================================================================
-- Migration: Copy Existing Cameras to Devices Table
-- ============================================================================

-- Migrate existing cameras to devices table
INSERT OR IGNORE INTO devices (
    device_id,
    zabbix_host_id,
    host_name,
    visible_name,
    device_type,
    ip_address,
    status,
    location,
    ngsi_ld_json,
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
    status,
    location,
    ngsi_ld_json,
    created_at,
    updated_at
FROM cameras;

-- ============================================================================
-- Verification Queries
-- ============================================================================

-- Count tables
SELECT 'Tables created:' as info;
SELECT name FROM sqlite_master WHERE type='table' AND name IN ('devices', 'host_groups') ORDER BY name;

-- Count records
SELECT 'Devices count:' as info, COUNT(*) as count FROM devices;
SELECT 'Host groups count:' as info, COUNT(*) as count FROM host_groups;
SELECT 'Configuration count:' as info, COUNT(*) as count FROM configuration WHERE key LIKE '%sync%';
