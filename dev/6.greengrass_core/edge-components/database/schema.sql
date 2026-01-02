-- ============================================================================
-- Greengrass Edge SQLite Database Schema
-- Version: 3.0.0 (Unified Devices Architecture)
-- Purpose: Local data storage for device registry and incident management
-- Migration: cameras table → VIEW (backward compatible)
-- ============================================================================

-- Enable performance optimizations
PRAGMA journal_mode = WAL;
PRAGMA foreign_keys = ON;
PRAGMA synchronous = NORMAL;
PRAGMA cache_size = -64000;  -- 64MB cache

-- ============================================================================
-- Devices Table (Universal Device Registry)
-- ============================================================================
-- Stores ALL monitored devices: cameras, servers, network devices, etc.
-- Replaces legacy cameras table with unified architecture
CREATE TABLE IF NOT EXISTS devices (
    device_id TEXT PRIMARY KEY,
    zabbix_host_id TEXT UNIQUE NOT NULL,
    host_name TEXT NOT NULL,
    visible_name TEXT,
    device_type TEXT DEFAULT 'unknown',  -- camera | server | network | unknown
    ip_address TEXT,
    port TEXT DEFAULT '10050',
    status TEXT DEFAULT 'unknown',  -- online | offline | unknown | disabled

    -- Zabbix metadata
    available INTEGER DEFAULT 0,  -- 0=unknown, 1=available, 2=unavailable
    maintenance_status INTEGER DEFAULT 0,  -- 0=no maintenance, 1=in maintenance
    lastchange INTEGER,  -- Unix timestamp of last change (for incremental sync)

    -- Host group associations
    host_groups TEXT,  -- Comma-separated Zabbix groupids

    -- Location and tags
    location TEXT,
    tags TEXT,  -- JSON array of tags

    -- Camera-specific fields (when device_type='camera')
    model TEXT,
    firmware_version TEXT,
    site_id TEXT DEFAULT 'site-001',

    -- NGSI-LD representation
    ngsi_ld_json TEXT NOT NULL,

    -- Timestamps
    first_seen DATETIME DEFAULT CURRENT_TIMESTAMP,
    last_seen DATETIME DEFAULT CURRENT_TIMESTAMP,
    created_at DATETIME DEFAULT CURRENT_TIMESTAMP,
    updated_at DATETIME DEFAULT CURRENT_TIMESTAMP,

    UNIQUE(ip_address, port)
);

CREATE INDEX idx_devices_zabbix_host ON devices(zabbix_host_id);
CREATE INDEX idx_devices_type ON devices(device_type);
CREATE INDEX idx_devices_status ON devices(status);
CREATE INDEX idx_devices_ip ON devices(ip_address);
CREATE INDEX idx_devices_updated ON devices(updated_at);
CREATE INDEX idx_devices_lastchange ON devices(lastchange);

-- ============================================================================
-- Host Groups Table (Zabbix host groups)
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

CREATE INDEX idx_hostgroups_name ON host_groups(name);
CREATE INDEX idx_hostgroups_updated ON host_groups(updated_at);

-- ============================================================================
-- Cameras VIEW (Backward Compatibility)
-- ============================================================================
-- Legacy cameras table replaced with VIEW for 100% backward compatibility
-- All existing queries work unchanged: SELECT/INSERT/UPDATE on cameras
CREATE VIEW IF NOT EXISTS cameras AS
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
-- Incidents Table
-- ============================================================================
-- Stores device incidents (offline events, alerts, problems)
-- Note: camera_id field maintained for backward compatibility
CREATE TABLE IF NOT EXISTS incidents (
    incident_id TEXT PRIMARY KEY,
    camera_id TEXT NOT NULL,  -- Maps to device_id (backward compatible)
    zabbix_event_id TEXT UNIQUE,
    incident_type TEXT NOT NULL, -- camera_offline | camera_online | sensor_fault
    severity TEXT NOT NULL,      -- low | medium | high | critical
    detected_at DATETIME NOT NULL,
    resolved_at DATETIME,
    duration_seconds INTEGER,
    ngsi_ld_json TEXT NOT NULL,
    synced_to_cloud INTEGER DEFAULT 0, -- 0 = pending, 1 = synced
    retry_count INTEGER DEFAULT 0,
    last_retry_at DATETIME,
    error_message TEXT,
    created_at DATETIME DEFAULT CURRENT_TIMESTAMP
    -- Note: Foreign key to devices (camera_id = device_id)
);

CREATE INDEX idx_incidents_camera ON incidents(camera_id);
CREATE INDEX idx_incidents_type ON incidents(incident_type);
CREATE INDEX idx_incidents_severity ON incidents(severity);
CREATE INDEX idx_incidents_synced ON incidents(synced_to_cloud);
CREATE INDEX idx_incidents_detected ON incidents(detected_at);
CREATE INDEX idx_incidents_zabbix_event ON incidents(zabbix_event_id);

-- ============================================================================
-- Message Queue Table
-- ============================================================================
-- Persistent queue for cloud-bound MQTT messages (offline resilience)
CREATE TABLE IF NOT EXISTS message_queue (
    message_id TEXT PRIMARY KEY,
    topic TEXT NOT NULL,
    payload TEXT NOT NULL,
    priority INTEGER DEFAULT 3,  -- 1 (critical) to 5 (low)
    status TEXT DEFAULT 'pending', -- pending | sent | failed
    scheduled_at DATETIME DEFAULT CURRENT_TIMESTAMP,
    attempts INTEGER DEFAULT 0,
    max_attempts INTEGER DEFAULT 3,
    last_attempt_at DATETIME,
    last_error TEXT,
    created_at DATETIME DEFAULT CURRENT_TIMESTAMP
);

CREATE INDEX idx_queue_status ON message_queue(status);
CREATE INDEX idx_queue_priority ON message_queue(priority, scheduled_at);
CREATE INDEX idx_queue_scheduled ON message_queue(scheduled_at);

-- ============================================================================
-- Sync Log Table
-- ============================================================================
-- Audit trail for synchronization operations
CREATE TABLE IF NOT EXISTS sync_log (
    log_id INTEGER PRIMARY KEY AUTOINCREMENT,
    sync_type TEXT NOT NULL,      -- device_inventory | incident | message_queue
    sync_timestamp DATETIME DEFAULT CURRENT_TIMESTAMP,
    records_synced INTEGER DEFAULT 0,
    status TEXT NOT NULL,         -- success | failed | partial
    error_message TEXT,
    duration_ms INTEGER,
    checksum TEXT
);

CREATE INDEX idx_sync_log_type ON sync_log(sync_type);
CREATE INDEX idx_sync_log_timestamp ON sync_log(sync_timestamp);

-- ============================================================================
-- Configuration Table
-- ============================================================================
-- Component settings and runtime configuration (key-value store)
CREATE TABLE IF NOT EXISTS configuration (
    key TEXT PRIMARY KEY,
    value TEXT NOT NULL,
    description TEXT,
    updated_at DATETIME DEFAULT CURRENT_TIMESTAMP
);

-- ============================================================================
-- Default Configuration Values
-- ============================================================================
INSERT OR IGNORE INTO configuration (key, value, description) VALUES
    ('site_id', 'site-001', 'Site identifier for this Greengrass Core'),
    ('zabbix_api_url', 'http://localhost:8080/api_jsonrpc.php', 'Zabbix API endpoint'),
    ('zabbix_username', 'Admin', 'Zabbix API username'),
    ('zabbix_password', 'zabbix', 'Zabbix API password (use secure storage)'),
    ('zabbix_webhook_port', '8081', 'Port for Zabbix webhook receiver'),
    ('iot_core_topic_incidents', 'aismc/site-001/incidents', 'MQTT topic for incidents'),
    ('iot_core_topic_devices', 'aismc/site-001/devices', 'MQTT topic for device registry'),
    ('sync_schedule', '0 2 * * *', 'Cron schedule for device sync (daily at 2AM)'),
    ('sync_enabled', 'true', 'Enable/disable scheduled device registry sync'),
    ('incremental_sync', 'true', 'Enable incremental sync (only changed devices)'),
    ('last_sync_timestamp', '', 'ISO8601 timestamp of last successful sync'),
    ('last_sync_unix', '0', 'Unix timestamp for incremental sync queries'),
    ('total_devices', '0', 'Total number of devices registered'),
    ('total_host_groups', '0', 'Total number of host groups synced'),
    ('retry_interval_seconds', '60', 'Retry interval for failed messages'),
    ('max_retry_attempts', '3', 'Maximum retry attempts for failed messages'),
    ('database_version', '3.0.0', 'Schema version (unified devices)'),
    ('deployed_at', datetime('now'), 'Database deployment timestamp');

-- ============================================================================
-- Triggers
-- ============================================================================
-- Auto-update timestamp triggers

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

CREATE TRIGGER IF NOT EXISTS update_config_timestamp
AFTER UPDATE ON configuration
BEGIN
    UPDATE configuration SET updated_at = CURRENT_TIMESTAMP WHERE key = NEW.key;
END;

-- ============================================================================
-- Views for Common Queries
-- ============================================================================

-- Active cameras (not offline) - uses cameras VIEW
CREATE VIEW IF NOT EXISTS v_active_cameras AS
SELECT * FROM cameras WHERE status != 'offline' ORDER BY updated_at DESC;

-- Offline cameras - uses cameras VIEW
CREATE VIEW IF NOT EXISTS v_offline_cameras AS
SELECT * FROM cameras WHERE status = 'offline' ORDER BY last_seen DESC;

-- Pending sync incidents
CREATE VIEW IF NOT EXISTS v_pending_incidents AS
SELECT * FROM incidents
WHERE synced_to_cloud = 0
AND retry_count < 3
ORDER BY
    CASE severity
        WHEN 'critical' THEN 1
        WHEN 'high' THEN 2
        WHEN 'medium' THEN 3
        ELSE 4
    END,
    detected_at ASC;

-- Failed messages in queue
CREATE VIEW IF NOT EXISTS v_failed_messages AS
SELECT * FROM message_queue
WHERE status = 'failed'
ORDER BY priority ASC, created_at DESC;

-- ============================================================================
-- Database Metadata (Schema Versioning)
-- ============================================================================
CREATE TABLE IF NOT EXISTS _metadata (
    schema_version TEXT PRIMARY KEY,
    applied_at DATETIME DEFAULT CURRENT_TIMESTAMP,
    description TEXT
);

INSERT OR REPLACE INTO _metadata (schema_version, description) VALUES
    ('1.0.0', 'Initial schema for camera monitoring and incident management'),
    ('2.0.0', 'Added devices and host_groups tables for universal device registry'),
    ('3.0.0', 'Unified devices table - cameras migrated to VIEW for backward compatibility');

-- ============================================================================
-- Schema Validation Queries
-- ============================================================================
-- Use these queries to verify schema deployment:
--
-- 1. List all objects:
--    SELECT name, type FROM sqlite_master WHERE type IN ('table', 'view', 'index') ORDER BY type, name;
--
-- 2. Verify cameras is a VIEW (not table):
--    SELECT type FROM sqlite_master WHERE name='cameras';  -- Expected: view
--
-- 3. Count devices:
--    SELECT device_type, COUNT(*) FROM devices GROUP BY device_type;
--
-- 4. Verify cameras VIEW matches devices:
--    SELECT COUNT(*) FROM cameras;
--    SELECT COUNT(*) FROM devices WHERE device_type='camera';
--
-- 5. Schema version:
--    SELECT * FROM _metadata ORDER BY applied_at DESC;
--
