# Phase 2: Zabbix-Greengrass Integration - Implementation Plan

**Document Version**: 1.0
**Date**: 2025-12-31
**Status**: Ready for Implementation
**Prerequisite**: Phase 1 (AWS Cloud Infrastructure) ✅ COMPLETED

---

## Executive Summary

This document provides a detailed implementation plan for integrating Zabbix monitoring system with AWS IoT Greengrass to create an edge-to-cloud camera incident monitoring solution.

**Architecture Overview**:
```
Camera Offline → Zabbix → Greengrass → AWS IoT Core → DynamoDB → Grafana/SNS
```

**Key Components**:
1. Zabbix Monitoring Server (localhost) - Camera offline detection
2. AWS IoT Greengrass Core (GreengrassCore-site001-hanoi) - Edge processing
3. SQLite Local Database - Offline buffering
4. Custom Greengrass Components - Event processing and forwarding
5. AWS IoT Core - Cloud ingestion
6. DynamoDB - Data persistence
7. Grafana - Visualization

---

## Phase 2 Implementation Timeline

| Priority | Task | Estimated Time | Dependencies |
|----------|------|----------------|--------------|
| P1 | SQLite Database Setup | 0.5 day | None |
| P1 | Database DAO Layer | 1 day | SQLite Schema |
| P2 | Zabbix Server Configuration | 1 day | None |
| P2 | Zabbix Webhook Testing | 0.5 day | Zabbix Config |
| P3 | ZabbixEventSubscriber Component | 2 days | DAO Layer, Zabbix |
| P3 | IncidentMessageForwarder Component | 1.5 days | DAO Layer |
| P3 | CameraRegistrySync Component | 1.5 days | DAO Layer, Zabbix API |
| P4 | Component Packaging & Upload | 0.5 day | All Components |
| P4 | Greengrass Deployment | 0.5 day | Component Upload |
| P5 | End-to-End Testing | 2 days | Deployment |
| P5 | Offline Operation Testing | 1 day | E2E Testing |
| **TOTAL** | | **12 days** | |

---

## Priority 1: Local Database Setup

### Step 1.1: Create SQLite Database Schema

**Location**: `/var/greengrass/database/greengrass.db`

**Schema Definition**:

```sql
-- Enable WAL mode for concurrent access
PRAGMA journal_mode = WAL;
PRAGMA foreign_keys = ON;
PRAGMA synchronous = NORMAL;

-- Camera Registry Table
CREATE TABLE IF NOT EXISTS cameras (
    camera_id TEXT PRIMARY KEY,
    zabbix_host_id TEXT UNIQUE NOT NULL,
    ip_address TEXT NOT NULL,
    hostname TEXT,
    location TEXT,
    site_id TEXT NOT NULL DEFAULT 'site-001',
    device_type TEXT DEFAULT 'IP_Camera',
    model TEXT,
    firmware_version TEXT,
    status TEXT DEFAULT 'unknown', -- online | offline | unknown
    last_seen DATETIME,
    ngsi_ld_json TEXT NOT NULL,
    created_at DATETIME DEFAULT CURRENT_TIMESTAMP,
    updated_at DATETIME DEFAULT CURRENT_TIMESTAMP,
    UNIQUE(ip_address)
);

CREATE INDEX idx_cameras_site ON cameras(site_id);
CREATE INDEX idx_cameras_status ON cameras(status);
CREATE INDEX idx_cameras_updated ON cameras(updated_at);
CREATE INDEX idx_cameras_zabbix_host ON cameras(zabbix_host_id);

-- Incidents Table
CREATE TABLE IF NOT EXISTS incidents (
    incident_id TEXT PRIMARY KEY,
    camera_id TEXT NOT NULL,
    zabbix_event_id TEXT UNIQUE,
    incident_type TEXT NOT NULL, -- camera_offline | camera_online
    severity TEXT NOT NULL,      -- low | medium | high | critical
    detected_at DATETIME NOT NULL,
    resolved_at DATETIME,
    duration_seconds INTEGER,
    ngsi_ld_json TEXT NOT NULL,
    synced_to_cloud INTEGER DEFAULT 0, -- 0 = pending, 1 = synced
    retry_count INTEGER DEFAULT 0,
    last_retry_at DATETIME,
    error_message TEXT,
    created_at DATETIME DEFAULT CURRENT_TIMESTAMP,
    FOREIGN KEY(camera_id) REFERENCES cameras(camera_id)
);

CREATE INDEX idx_incidents_camera ON incidents(camera_id);
CREATE INDEX idx_incidents_type ON incidents(incident_type);
CREATE INDEX idx_incidents_severity ON incidents(severity);
CREATE INDEX idx_incidents_synced ON incidents(synced_to_cloud);
CREATE INDEX idx_incidents_detected ON incidents(detected_at);
CREATE INDEX idx_incidents_zabbix_event ON incidents(zabbix_event_id);

-- Message Queue Table (for retry logic)
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

-- Sync Log Table (audit trail)
CREATE TABLE IF NOT EXISTS sync_log (
    log_id INTEGER PRIMARY KEY AUTOINCREMENT,
    sync_type TEXT NOT NULL,      -- camera_registry | incident | message_queue
    sync_timestamp DATETIME DEFAULT CURRENT_TIMESTAMP,
    records_synced INTEGER DEFAULT 0,
    status TEXT NOT NULL,         -- success | failed | partial
    error_message TEXT,
    duration_ms INTEGER,
    checksum TEXT
);

CREATE INDEX idx_sync_log_type ON sync_log(sync_type);
CREATE INDEX idx_sync_log_timestamp ON sync_log(sync_timestamp);

-- Configuration Table (component settings)
CREATE TABLE IF NOT EXISTS configuration (
    key TEXT PRIMARY KEY,
    value TEXT NOT NULL,
    description TEXT,
    updated_at DATETIME DEFAULT CURRENT_TIMESTAMP
);

-- Insert default configurations
INSERT OR IGNORE INTO configuration (key, value, description) VALUES
    ('site_id', 'site-001', 'Site identifier for this Greengrass Core'),
    ('zabbix_api_url', 'http://localhost/zabbix/api_jsonrpc.php', 'Zabbix API endpoint'),
    ('zabbix_webhook_port', '8080', 'Port for Zabbix webhook receiver'),
    ('iot_core_topic_incidents', 'cameras/site-001/incidents', 'MQTT topic for incidents'),
    ('iot_core_topic_registry', 'cameras/site-001/registry', 'MQTT topic for registry'),
    ('camera_sync_schedule', '0 2 * * *', 'Cron schedule for camera registry sync (daily at 2AM)'),
    ('last_camera_sync', '', 'Timestamp of last successful camera sync'),
    ('total_cameras', '0', 'Total number of cameras registered'),
    ('retry_interval_seconds', '60', 'Retry interval for failed messages'),
    ('max_retry_attempts', '3', 'Maximum retry attempts for failed messages');

-- Trigger to update updated_at timestamp
CREATE TRIGGER IF NOT EXISTS update_cameras_timestamp
AFTER UPDATE ON cameras
BEGIN
    UPDATE cameras SET updated_at = CURRENT_TIMESTAMP WHERE camera_id = NEW.camera_id;
END;

CREATE TRIGGER IF NOT EXISTS update_config_timestamp
AFTER UPDATE ON configuration
BEGIN
    UPDATE configuration SET updated_at = CURRENT_TIMESTAMP WHERE key = NEW.key;
END;
```

**Implementation Script**:

```bash
#!/bin/bash
# File: /greengrass/v2/scripts/setup-database.sh

set -e

DB_DIR="/var/greengrass/database"
DB_FILE="$DB_DIR/greengrass.db"
SCHEMA_FILE="/greengrass/v2/database/schema.sql"

echo "Setting up SQLite database for Greengrass..."

# Create database directory
sudo mkdir -p "$DB_DIR"
sudo chown ggc_user:ggc_group "$DB_DIR"
sudo chmod 755 "$DB_DIR"

# Create database and apply schema
if [ -f "$SCHEMA_FILE" ]; then
    sudo -u ggc_user sqlite3 "$DB_FILE" < "$SCHEMA_FILE"
    echo "✅ Database schema created successfully"
else
    echo "❌ Schema file not found: $SCHEMA_FILE"
    exit 1
fi

# Verify database
echo "Verifying database..."
sudo -u ggc_user sqlite3 "$DB_FILE" "SELECT name FROM sqlite_master WHERE type='table';"

# Set permissions
sudo chmod 660 "$DB_FILE"
sudo chown ggc_user:ggc_group "$DB_FILE"

echo "✅ Database setup completed: $DB_FILE"
```

### Step 1.2: Implement Database DAO Layer

**File Structure**:
```
/greengrass/v2/components/common/
├── database/
│   ├── __init__.py
│   ├── connection.py          # Database connection manager
│   ├── dao.py                  # Data Access Objects
│   └── models.py               # Data models (Pydantic or dataclasses)
└── utils/
    ├── __init__.py
    └── ngsi_ld.py              # NGSI-LD transformer utilities
```

**connection.py**:

```python
"""
Database Connection Manager with connection pooling
"""
import sqlite3
import logging
from contextlib import contextmanager
from typing import Optional
from threading import Lock

logger = logging.getLogger(__name__)

class DatabaseManager:
    """Singleton database connection manager"""

    _instance: Optional['DatabaseManager'] = None
    _lock = Lock()

    def __new__(cls, db_path: str = "/var/greengrass/database/greengrass.db"):
        if cls._instance is None:
            with cls._lock:
                if cls._instance is None:
                    cls._instance = super().__new__(cls)
                    cls._instance._initialize(db_path)
        return cls._instance

    def _initialize(self, db_path: str):
        """Initialize database manager"""
        self.db_path = db_path
        self._verify_database()
        logger.info(f"DatabaseManager initialized with {db_path}")

    def _verify_database(self):
        """Verify database exists and is accessible"""
        try:
            with self.get_connection() as conn:
                cursor = conn.cursor()
                cursor.execute("SELECT COUNT(*) FROM sqlite_master WHERE type='table'")
                table_count = cursor.fetchone()[0]
                logger.info(f"Database verified: {table_count} tables found")
        except Exception as e:
            logger.error(f"Database verification failed: {e}")
            raise

    @contextmanager
    def get_connection(self):
        """
        Context manager for database connections
        Automatically handles commit/rollback and close
        """
        conn = sqlite3.connect(
            self.db_path,
            check_same_thread=False,
            timeout=30.0
        )
        conn.row_factory = sqlite3.Row  # Return rows as dictionaries

        try:
            yield conn
            conn.commit()
        except Exception as e:
            conn.rollback()
            logger.error(f"Database transaction failed: {e}")
            raise
        finally:
            conn.close()

    def execute_query(self, query: str, params: tuple = ()):
        """Execute a read query and return results"""
        with self.get_connection() as conn:
            cursor = conn.cursor()
            cursor.execute(query, params)
            return [dict(row) for row in cursor.fetchall()]

    def execute_update(self, query: str, params: tuple = ()):
        """Execute an insert/update/delete query"""
        with self.get_connection() as conn:
            cursor = conn.cursor()
            cursor.execute(query, params)
            return cursor.rowcount
```

**dao.py**:

```python
"""
Data Access Objects for all database tables
"""
import json
import logging
from datetime import datetime
from typing import List, Dict, Optional
from .connection import DatabaseManager

logger = logging.getLogger(__name__)

class CameraDAO:
    """Data Access Object for cameras table"""

    def __init__(self, db_manager: DatabaseManager):
        self.db = db_manager

    def insert(self, camera: Dict) -> str:
        """Insert a new camera"""
        with self.db.get_connection() as conn:
            cursor = conn.cursor()
            cursor.execute("""
                INSERT INTO cameras (
                    camera_id, zabbix_host_id, ip_address, hostname, location,
                    site_id, model, firmware_version, status, ngsi_ld_json
                ) VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?)
            """, (
                camera['camera_id'],
                camera['zabbix_host_id'],
                camera['ip_address'],
                camera.get('hostname'),
                camera.get('location'),
                camera.get('site_id', 'site-001'),
                camera.get('model'),
                camera.get('firmware_version'),
                camera.get('status', 'unknown'),
                json.dumps(camera['ngsi_ld'])
            ))
        logger.info(f"Inserted camera: {camera['camera_id']}")
        return camera['camera_id']

    def batch_upsert(self, cameras: List[Dict]) -> int:
        """Batch insert/update cameras (efficient for large datasets)"""
        count = 0
        with self.db.get_connection() as conn:
            cursor = conn.cursor()
            for camera in cameras:
                cursor.execute("""
                    INSERT INTO cameras (
                        camera_id, zabbix_host_id, ip_address, hostname, location,
                        site_id, model, firmware_version, status, ngsi_ld_json
                    ) VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?)
                    ON CONFLICT(camera_id) DO UPDATE SET
                        ip_address = excluded.ip_address,
                        hostname = excluded.hostname,
                        location = excluded.location,
                        model = excluded.model,
                        firmware_version = excluded.firmware_version,
                        status = excluded.status,
                        ngsi_ld_json = excluded.ngsi_ld_json,
                        updated_at = CURRENT_TIMESTAMP
                """, (
                    camera['camera_id'],
                    camera['zabbix_host_id'],
                    camera['ip_address'],
                    camera.get('hostname'),
                    camera.get('location'),
                    camera.get('site_id', 'site-001'),
                    camera.get('model'),
                    camera.get('firmware_version'),
                    camera.get('status', 'unknown'),
                    json.dumps(camera['ngsi_ld'])
                ))
                count += 1
        logger.info(f"Batch upserted {count} cameras")
        return count

    def get_by_id(self, camera_id: str) -> Optional[Dict]:
        """Get camera by ID"""
        results = self.db.execute_query(
            "SELECT * FROM cameras WHERE camera_id = ?",
            (camera_id,)
        )
        return results[0] if results else None

    def get_by_zabbix_host_id(self, zabbix_host_id: str) -> Optional[Dict]:
        """Get camera by Zabbix host ID"""
        results = self.db.execute_query(
            "SELECT * FROM cameras WHERE zabbix_host_id = ?",
            (zabbix_host_id,)
        )
        return results[0] if results else None

    def get_all(self, site_id: str = None, status: str = None) -> List[Dict]:
        """Get all cameras with optional filters"""
        query = "SELECT * FROM cameras WHERE 1=1"
        params = []

        if site_id:
            query += " AND site_id = ?"
            params.append(site_id)

        if status:
            query += " AND status = ?"
            params.append(status)

        query += " ORDER BY updated_at DESC"
        return self.db.execute_query(query, tuple(params))

    def update_status(self, camera_id: str, status: str):
        """Update camera status (online/offline)"""
        self.db.execute_update(
            "UPDATE cameras SET status = ?, last_seen = CURRENT_TIMESTAMP WHERE camera_id = ?",
            (status, camera_id)
        )
        logger.info(f"Updated camera {camera_id} status to {status}")

    def get_count(self) -> int:
        """Get total camera count"""
        result = self.db.execute_query("SELECT COUNT(*) as count FROM cameras")
        return result[0]['count']


class IncidentDAO:
    """Data Access Object for incidents table"""

    def __init__(self, db_manager: DatabaseManager):
        self.db = db_manager

    def insert(self, incident: Dict) -> str:
        """Insert a new incident"""
        with self.db.get_connection() as conn:
            cursor = conn.cursor()
            cursor.execute("""
                INSERT INTO incidents (
                    incident_id, camera_id, zabbix_event_id, incident_type,
                    severity, detected_at, ngsi_ld_json
                ) VALUES (?, ?, ?, ?, ?, ?, ?)
            """, (
                incident['incident_id'],
                incident['camera_id'],
                incident.get('zabbix_event_id'),
                incident['incident_type'],
                incident['severity'],
                incident['detected_at'],
                json.dumps(incident['ngsi_ld'])
            ))
        logger.info(f"Inserted incident: {incident['incident_id']}")
        return incident['incident_id']

    def update_resolved(self, incident_id: str, resolved_at: str):
        """Mark incident as resolved and calculate duration"""
        with self.db.get_connection() as conn:
            cursor = conn.cursor()
            cursor.execute("""
                UPDATE incidents
                SET resolved_at = ?,
                    duration_seconds = CAST((julianday(?) - julianday(detected_at)) * 86400 AS INTEGER)
                WHERE incident_id = ?
            """, (resolved_at, resolved_at, incident_id))
        logger.info(f"Resolved incident: {incident_id}")

    def get_pending_sync(self, limit: int = 100) -> List[Dict]:
        """Get incidents pending cloud sync"""
        return self.db.execute_query("""
            SELECT * FROM incidents
            WHERE synced_to_cloud = 0
            AND (retry_count < 3 OR last_retry_at IS NULL)
            ORDER BY
                CASE severity
                    WHEN 'critical' THEN 1
                    WHEN 'high' THEN 2
                    WHEN 'medium' THEN 3
                    ELSE 4
                END,
                detected_at ASC
            LIMIT ?
        """, (limit,))

    def mark_synced(self, incident_ids: List[str]):
        """Mark incidents as successfully synced to cloud"""
        with self.db.get_connection() as conn:
            cursor = conn.cursor()
            placeholders = ','.join('?' * len(incident_ids))
            cursor.execute(f"""
                UPDATE incidents
                SET synced_to_cloud = 1
                WHERE incident_id IN ({placeholders})
            """, incident_ids)
        logger.info(f"Marked {len(incident_ids)} incidents as synced")

    def increment_retry(self, incident_id: str, error_message: str = None):
        """Increment retry count for failed sync"""
        self.db.execute_update("""
            UPDATE incidents
            SET retry_count = retry_count + 1,
                last_retry_at = CURRENT_TIMESTAMP,
                error_message = ?
            WHERE incident_id = ?
        """, (error_message, incident_id))


class MessageQueueDAO:
    """Data Access Object for message_queue table"""

    def __init__(self, db_manager: DatabaseManager):
        self.db = db_manager

    def enqueue(self, message: Dict) -> str:
        """Add message to queue"""
        with self.db.get_connection() as conn:
            cursor = conn.cursor()
            cursor.execute("""
                INSERT INTO message_queue (
                    message_id, topic, payload, priority
                ) VALUES (?, ?, ?, ?)
            """, (
                message['message_id'],
                message['topic'],
                message['payload'],
                message.get('priority', 3)
            ))
        logger.debug(f"Enqueued message: {message['message_id']}")
        return message['message_id']

    def get_pending(self, limit: int = 50) -> List[Dict]:
        """Get pending messages ordered by priority"""
        return self.db.execute_query("""
            SELECT * FROM message_queue
            WHERE status = 'pending'
            AND attempts < max_attempts
            ORDER BY priority ASC, scheduled_at ASC
            LIMIT ?
        """, (limit,))

    def mark_sent(self, message_id: str):
        """Mark message as successfully sent"""
        self.db.execute_update("""
            UPDATE message_queue
            SET status = 'sent'
            WHERE message_id = ?
        """, (message_id,))

    def increment_attempt(self, message_id: str, error: str = None):
        """Increment send attempt counter"""
        with self.db.get_connection() as conn:
            cursor = conn.cursor()
            cursor.execute("""
                UPDATE message_queue
                SET attempts = attempts + 1,
                    last_attempt_at = CURRENT_TIMESTAMP,
                    last_error = ?,
                    status = CASE
                        WHEN attempts + 1 >= max_attempts THEN 'failed'
                        ELSE 'pending'
                    END
                WHERE message_id = ?
            """, (error, message_id))


class SyncLogDAO:
    """Data Access Object for sync_log table"""

    def __init__(self, db_manager: DatabaseManager):
        self.db = db_manager

    def log(self, sync_type: str, records_synced: int, status: str,
            error_message: str = None, duration_ms: int = None):
        """Log a sync operation"""
        with self.db.get_connection() as conn:
            cursor = conn.cursor()
            cursor.execute("""
                INSERT INTO sync_log (
                    sync_type, records_synced, status, error_message, duration_ms
                ) VALUES (?, ?, ?, ?, ?)
            """, (sync_type, records_synced, status, error_message, duration_ms))
        logger.info(f"Logged sync: {sync_type} - {status} ({records_synced} records)")

    def get_recent(self, sync_type: str = None, limit: int = 10) -> List[Dict]:
        """Get recent sync logs"""
        query = "SELECT * FROM sync_log"
        params = []

        if sync_type:
            query += " WHERE sync_type = ?"
            params.append(sync_type)

        query += " ORDER BY sync_timestamp DESC LIMIT ?"
        params.append(limit)

        return self.db.execute_query(query, tuple(params))


class ConfigurationDAO:
    """Data Access Object for configuration table"""

    def __init__(self, db_manager: DatabaseManager):
        self.db = db_manager

    def get(self, key: str) -> Optional[str]:
        """Get configuration value"""
        results = self.db.execute_query(
            "SELECT value FROM configuration WHERE key = ?",
            (key,)
        )
        return results[0]['value'] if results else None

    def set(self, key: str, value: str):
        """Set configuration value"""
        self.db.execute_update("""
            UPDATE configuration
            SET value = ?
            WHERE key = ?
        """, (value, key))
        logger.debug(f"Config updated: {key} = {value}")

    def get_all(self) -> Dict[str, str]:
        """Get all configurations as dictionary"""
        results = self.db.execute_query("SELECT key, value FROM configuration")
        return {row['key']: row['value'] for row in results}
```

**Testing Script**:

```bash
#!/bin/bash
# File: /greengrass/v2/scripts/test-database.sh

set -e

echo "Testing Database DAO Layer..."

# Test database connection
python3 << 'EOF'
import sys
sys.path.append('/greengrass/v2/components/common')

from database.connection import DatabaseManager
from database.dao import CameraDAO, IncidentDAO, ConfigurationDAO
import json
from datetime import datetime

# Initialize
db = DatabaseManager()
camera_dao = CameraDAO(db)
incident_dao = IncidentDAO(db)
config_dao = ConfigurationDAO(db)

print("✅ Database connection successful")

# Test Configuration
site_id = config_dao.get('site_id')
print(f"✅ Configuration: site_id = {site_id}")

# Test Camera Insert
test_camera = {
    'camera_id': 'CAM-TEST-001',
    'zabbix_host_id': '10001',
    'ip_address': '192.168.1.100',
    'hostname': 'camera-test-001',
    'location': 'Building A - Floor 1',
    'site_id': 'site-001',
    'model': 'Hikvision DS-2CD2345',
    'status': 'online',
    'ngsi_ld': {
        '@context': 'https://uri.etsi.org/ngsi-ld/v1/ngsi-ld-core-context.jsonld',
        'id': 'urn:ngsi-ld:Camera:CAM-TEST-001',
        'type': 'Camera',
        'ipAddress': {'type': 'Property', 'value': '192.168.1.100'}
    }
}

camera_id = camera_dao.insert(test_camera)
print(f"✅ Camera inserted: {camera_id}")

# Test Camera Retrieval
retrieved = camera_dao.get_by_id(camera_id)
print(f"✅ Camera retrieved: {retrieved['camera_id']}")

# Test Incident Insert
test_incident = {
    'incident_id': 'INC-TEST-001',
    'camera_id': camera_id,
    'zabbix_event_id': '12345',
    'incident_type': 'camera_offline',
    'severity': 'critical',
    'detected_at': datetime.utcnow().isoformat(),
    'ngsi_ld': {
        '@context': 'https://uri.etsi.org/ngsi-ld/v1/ngsi-ld-core-context.jsonld',
        'id': 'urn:ngsi-ld:Incident:INC-TEST-001',
        'type': 'CameraOfflineIncident'
    }
}

incident_id = incident_dao.insert(test_incident)
print(f"✅ Incident inserted: {incident_id}")

# Test Pending Sync
pending = incident_dao.get_pending_sync(limit=10)
print(f"✅ Pending incidents: {len(pending)}")

# Test Camera Count
count = camera_dao.get_count()
print(f"✅ Total cameras: {count}")

print("\n✅ All database tests passed!")
EOF
```

---

## Priority 2: Zabbix Integration

### Step 2.1: Verify Zabbix Installation

```bash
#!/bin/bash
# Verify Zabbix server is running

echo "Checking Zabbix installation..."

# Check Zabbix server service
if systemctl is-active --quiet zabbix-server; then
    echo "✅ Zabbix server is running"
    systemctl status zabbix-server | head -5
else
    echo "❌ Zabbix server is not running"
    exit 1
fi

# Check Zabbix web interface
if curl -s -o /dev/null -w "%{http_code}" http://localhost/zabbix/ | grep -q "200"; then
    echo "✅ Zabbix web interface is accessible"
else
    echo "❌ Zabbix web interface is not accessible"
fi

# Check Zabbix API
API_RESPONSE=$(curl -s -X POST http://localhost/zabbix/api_jsonrpc.php \
    -H "Content-Type: application/json-rpc" \
    -d '{"jsonrpc":"2.0","method":"apiinfo.version","params":[],"id":1}')

if echo "$API_RESPONSE" | grep -q "result"; then
    VERSION=$(echo "$API_RESPONSE" | jq -r '.result')
    echo "✅ Zabbix API is accessible (version: $VERSION)"
else
    echo "❌ Zabbix API is not accessible"
fi
```

### Step 2.2: Configure Zabbix for Camera Monitoring

**Create Host Group for Cameras**:

1. Login to Zabbix web interface: http://localhost/zabbix/
2. Go to Configuration → Host groups → Create host group
   - Name: "IP Cameras"
   - Save

**Create Camera Host Template**:

1. Go to Configuration → Templates → Create template
   - Template name: "Template IP Camera ICMP"
   - Groups: Templates/Network devices
   - Add Items:
     - Name: "ICMP ping"
     - Type: Simple check
     - Key: `icmpping`
     - Update interval: 30s
   - Add Triggers:
     - Name: "Camera {HOST.NAME} is offline"
     - Expression: `{Template IP Camera ICMP:icmpping.last()}=0`
     - Severity: High
     - Recovery expression: `{Template IP Camera ICMP:icmpping.last()}=1`

**Add Camera Hosts**:

```bash
# Script to add cameras via Zabbix API
# File: /greengrass/v2/scripts/add-cameras-to-zabbix.py

import requests
import json

ZABBIX_URL = "http://localhost/zabbix/api_jsonrpc.php"
ZABBIX_USER = "Admin"
ZABBIX_PASSWORD = "zabbix"

class ZabbixAPI:
    def __init__(self):
        self.auth_token = self.authenticate()

    def authenticate(self):
        """Authenticate with Zabbix API"""
        payload = {
            "jsonrpc": "2.0",
            "method": "user.login",
            "params": {
                "user": ZABBIX_USER,
                "password": ZABBIX_PASSWORD
            },
            "id": 1
        }
        response = requests.post(ZABBIX_URL, json=payload)
        return response.json()['result']

    def add_host(self, hostname, ip_address):
        """Add camera host to Zabbix"""
        payload = {
            "jsonrpc": "2.0",
            "method": "host.create",
            "params": {
                "host": hostname,
                "interfaces": [{
                    "type": 1,  # Agent
                    "main": 1,
                    "useip": 1,
                    "ip": ip_address,
                    "dns": "",
                    "port": "10050"
                }],
                "groups": [{"groupid": "8"}],  # IP Cameras group
                "templates": [{"templateid": "10001"}]  # Template IP Camera ICMP
            },
            "auth": self.auth_token,
            "id": 2
        }
        response = requests.post(ZABBIX_URL, json=payload)
        return response.json()

# Example: Add test camera
zapi = ZabbixAPI()
result = zapi.add_host("Camera-Test-001", "192.168.1.100")
print(f"Camera added: {result}")
```

### Step 2.3: Configure Zabbix Webhook for Greengrass

**Create Media Type (Webhook)**:

1. Go to Administration → Media types → Create media type
   - Name: "Greengrass Webhook"
   - Type: Webhook
   - Parameters:
     - URL: `http://localhost:8080/zabbix/events`
     - HTTPmethod: POST
     - Message format: JSON
   - Script:
     ```javascript
     var req = new HttpRequest();
     req.addHeader('Content-Type: application/json');

     var payload = {
         event_id: value.get('event.id'),
         event_name: value.get('event.name'),
         event_severity: value.get('event.severity'),
         event_status: value.get('event.value'),  // 0=OK, 1=PROBLEM
         host_id: value.get('host.id'),
         host_name: value.get('host.name'),
         host_ip: value.get('host.ip'),
         trigger_description: value.get('trigger.description'),
         trigger_status: value.get('trigger.status'),
         timestamp: new Date().toISOString()
     };

     var response = req.post(params.URL, JSON.stringify(payload));

     if (response !== null) {
         Zabbix.log(4, 'Greengrass webhook response: ' + response);
     }

     return response;
     ```

**Create Action for Camera Offline Events**:

1. Go to Configuration → Actions → Create action
   - Name: "Send to Greengrass on camera offline"
   - Conditions:
     - Trigger severity >= High
     - Host group = "IP Cameras"
   - Operations:
     - Send message to users: Admin via Greengrass Webhook
   - Recovery operations:
     - Send message to users: Admin via Greengrass Webhook

---

## Priority 3: Custom Greengrass Components Development

### Step 3.1: ZabbixEventSubscriber Component

**Component Structure**:
```
/greengrass/v2/components/artifacts/com.aismc.ZabbixEventSubscriber/1.0.0/
├── recipe.yaml
├── main.py
├── zabbix_webhook_handler.py
├── requirements.txt
└── config.json
```

**recipe.yaml**:

```yaml
---
RecipeFormatVersion: '2020-01-25'
ComponentName: com.aismc.ZabbixEventSubscriber
ComponentVersion: '1.0.0'
ComponentDescription: |
  HTTP webhook server to receive Zabbix problem/recovery events,
  store in local SQLite database, and publish to local MQTT for forwarding.
ComponentPublisher: AISMC
ComponentDependencies:
  aws.greengrass.Nucleus:
    VersionRequirement: '>=2.0.0'

Manifests:
  - Platform:
      os: linux
    Lifecycle:
      Install:
        Script: |
          pip3 install -r {artifacts:path}/requirements.txt
          mkdir -p /var/greengrass/logs/zabbix-subscriber

      Run:
        Script: |
          python3 -u {artifacts:path}/main.py \
            --config {artifacts:path}/config.json \
            --port {configuration:/webhook_port} \
            --site-id {configuration:/site_id}
        RequiresPrivilege: false

      Shutdown:
        Script: |
          pkill -f "main.py"
          timeout: 10

    Artifacts:
      - URI: s3://aismc-greengrass-components/ZabbixEventSubscriber/1.0.0/main.py
      - URI: s3://aismc-greengrass-components/ZabbixEventSubscriber/1.0.0/zabbix_webhook_handler.py
      - URI: s3://aismc-greengrass-components/ZabbixEventSubscriber/1.0.0/requirements.txt
      - URI: s3://aismc-greengrass-components/ZabbixEventSubscriber/1.0.0/config.json

ComponentConfiguration:
  DefaultConfiguration:
    webhook_port: 8080
    site_id: "site-001"
    mqtt_topic: "local/incidents"
    log_level: "INFO"
```

**main.py** (see next section for full implementation)

**requirements.txt**:
```
flask==2.3.0
pydantic==2.0.0
requests==2.31.0
```

[Continue with detailed implementation code for all 3 custom components...]

---

## Implementation Checklist

### Phase 2 Readiness

- [ ] SQLite database schema created and tested
- [ ] Database DAO layer implemented and tested
- [ ] Zabbix server verified and accessible
- [ ] Zabbix webhook configured
- [ ] Test camera added to Zabbix
- [ ] ZabbixEventSubscriber component developed
- [ ] IncidentMessageForwarder component developed
- [ ] CameraRegistrySync component developed
- [ ] Components packaged and uploaded to S3
- [ ] Deployment configuration created
- [ ] Components deployed to Greengrass
- [ ] End-to-end test completed
- [ ] Offline operation test completed

---

**Document Status**: READY FOR IMPLEMENTATION
**Next Action**: Begin Priority 1 - SQLite Database Setup
