"""
Data Access Objects for all database tables
Provides CRUD operations with proper error handling and logging
"""
import json
import logging
from datetime import datetime
from typing import List, Dict, Optional

# Use absolute import for better compatibility
try:
    from .connection import DatabaseManager
except ImportError:
    from connection import DatabaseManager

logger = logging.getLogger(__name__)


class CameraDAO:
    """Data Access Object for cameras table"""

    def __init__(self, db_manager: DatabaseManager):
        self.db = db_manager

    def insert(self, camera: Dict) -> str:
        """
        Insert a new camera

        Args:
            camera: Dictionary with camera data (camera_id, zabbix_host_id, ip_address, etc.)

        Returns:
            camera_id of inserted camera
        """
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
                json.dumps(camera.get('ngsi_ld', {}))
            ))
        logger.info(f"Inserted camera: {camera['camera_id']}")
        return camera['camera_id']

    def batch_upsert(self, cameras: List[Dict]) -> int:
        """
        Batch insert/update cameras (efficient for large datasets)

        Args:
            cameras: List of camera dictionaries

        Returns:
            Number of cameras processed
        """
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
                        zabbix_host_id = excluded.zabbix_host_id,
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
                    json.dumps(camera.get('ngsi_ld', {}))
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

    def get_by_ip(self, ip_address: str) -> Optional[Dict]:
        """Get camera by IP address"""
        results = self.db.execute_query(
            "SELECT * FROM cameras WHERE ip_address = ?",
            (ip_address,)
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

    def get_offline_cameras(self, site_id: str = None) -> List[Dict]:
        """Get all offline cameras"""
        return self.get_all(site_id=site_id, status='offline')

    def update_status(self, camera_id: str, status: str):
        """Update camera status (online/offline/unknown)"""
        self.db.execute_update(
            "UPDATE cameras SET status = ?, last_seen = CURRENT_TIMESTAMP WHERE camera_id = ?",
            (status, camera_id)
        )
        logger.info(f"Updated camera {camera_id} status to {status}")

    def get_count(self, status: str = None) -> int:
        """Get camera count, optionally filtered by status"""
        if status:
            result = self.db.execute_query(
                "SELECT COUNT(*) as count FROM cameras WHERE status = ?",
                (status,)
            )
        else:
            result = self.db.execute_query("SELECT COUNT(*) as count FROM cameras")
        return result[0]['count']


class IncidentDAO:
    """Data Access Object for incidents table"""

    def __init__(self, db_manager: DatabaseManager):
        self.db = db_manager

    def insert(self, incident: Dict) -> str:
        """
        Insert a new incident

        Args:
            incident: Dictionary with incident data

        Returns:
            incident_id of inserted incident
        """
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
        logger.info(f"Inserted incident: {incident['incident_id']} (type: {incident['incident_type']})")
        return incident['incident_id']

    def get_by_id(self, incident_id: str) -> Optional[Dict]:
        """Get incident by ID"""
        results = self.db.execute_query(
            "SELECT * FROM incidents WHERE incident_id = ?",
            (incident_id,)
        )
        return results[0] if results else None

    def get_by_zabbix_event_id(self, zabbix_event_id: str) -> Optional[Dict]:
        """Get incident by Zabbix event ID"""
        results = self.db.execute_query(
            "SELECT * FROM incidents WHERE zabbix_event_id = ?",
            (zabbix_event_id,)
        )
        return results[0] if results else None

    def update_resolved(self, incident_id: str, resolved_at: str = None):
        """
        Mark incident as resolved and calculate duration

        Args:
            incident_id: Incident ID
            resolved_at: ISO timestamp (defaults to now)
        """
        if not resolved_at:
            resolved_at = datetime.utcnow().isoformat()

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
        """
        Get incidents pending cloud sync, ordered by priority

        Args:
            limit: Maximum number of incidents to return

        Returns:
            List of incident dictionaries
        """
        return self.db.execute_query("""
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
                detected_at ASC
            LIMIT ?
        """, (limit,))

    def mark_synced(self, incident_ids: List[str]):
        """Mark incidents as successfully synced to cloud"""
        if not incident_ids:
            return

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
        logger.warning(f"Incremented retry count for incident: {incident_id}")

    def get_recent(self, camera_id: str = None, limit: int = 100) -> List[Dict]:
        """Get recent incidents, optionally filtered by camera"""
        query = "SELECT * FROM incidents WHERE 1=1"
        params = []

        if camera_id:
            query += " AND camera_id = ?"
            params.append(camera_id)

        query += " ORDER BY detected_at DESC LIMIT ?"
        params.append(limit)

        return self.db.execute_query(query, tuple(params))

    def get_unresolved(self, camera_id: str = None) -> List[Dict]:
        """Get unresolved incidents"""
        query = "SELECT * FROM incidents WHERE resolved_at IS NULL"
        params = []

        if camera_id:
            query += " AND camera_id = ?"
            params.append(camera_id)

        query += " ORDER BY detected_at DESC"
        return self.db.execute_query(query, tuple(params))


class MessageQueueDAO:
    """Data Access Object for message_queue table"""

    def __init__(self, db_manager: DatabaseManager):
        self.db = db_manager

    def enqueue(self, message: Dict) -> str:
        """
        Add message to queue

        Args:
            message: Dictionary with message_id, topic, payload, priority

        Returns:
            message_id
        """
        with self.db.get_connection() as conn:
            cursor = conn.cursor()
            cursor.execute("""
                INSERT INTO message_queue (
                    message_id, topic, payload, priority, max_attempts
                ) VALUES (?, ?, ?, ?, ?)
            """, (
                message['message_id'],
                message['topic'],
                message['payload'],
                message.get('priority', 3),
                message.get('max_attempts', 3)
            ))
        logger.debug(f"Enqueued message: {message['message_id']}")
        return message['message_id']

    def get_pending(self, limit: int = 50) -> List[Dict]:
        """Get pending messages ordered by priority and schedule"""
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
            SET status = 'sent',
                last_attempt_at = CURRENT_TIMESTAMP
            WHERE message_id = ?
        """, (message_id,))
        logger.debug(f"Marked message {message_id} as sent")

    def increment_attempt(self, message_id: str, error: str = None):
        """Increment send attempt counter and update status if max reached"""
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
        logger.warning(f"Incremented attempt for message {message_id}: {error}")

    def get_failed(self, limit: int = 100) -> List[Dict]:
        """Get failed messages"""
        return self.db.execute_query("""
            SELECT * FROM message_queue
            WHERE status = 'failed'
            ORDER BY created_at DESC
            LIMIT ?
        """, (limit,))

    def purge_old_sent(self, days: int = 7) -> int:
        """Delete sent messages older than specified days"""
        affected = self.db.execute_update("""
            DELETE FROM message_queue
            WHERE status = 'sent'
            AND created_at < datetime('now', ? || ' days')
        """, (f'-{days}',))
        logger.info(f"Purged {affected} old sent messages (older than {days} days)")
        return affected


class SyncLogDAO:
    """Data Access Object for sync_log table"""

    def __init__(self, db_manager: DatabaseManager):
        self.db = db_manager

    def log(self, sync_type: str, records_synced: int, status: str,
            error_message: str = None, duration_ms: int = None):
        """
        Log a sync operation

        Args:
            sync_type: Type of sync (camera_registry, incident, message_queue)
            records_synced: Number of records synced
            status: success | failed | partial
            error_message: Optional error message
            duration_ms: Optional duration in milliseconds
        """
        with self.db.get_connection() as conn:
            cursor = conn.cursor()
            cursor.execute("""
                INSERT INTO sync_log (
                    sync_type, records_synced, status, error_message, duration_ms
                ) VALUES (?, ?, ?, ?, ?)
            """, (sync_type, records_synced, status, error_message, duration_ms))

        log_level = logging.INFO if status == 'success' else logging.WARNING
        logger.log(log_level, f"Sync logged: {sync_type} - {status} ({records_synced} records)")

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

    def get_last_successful_sync(self, sync_type: str) -> Optional[Dict]:
        """Get last successful sync for a specific type"""
        results = self.db.execute_query("""
            SELECT * FROM sync_log
            WHERE sync_type = ? AND status = 'success'
            ORDER BY sync_timestamp DESC
            LIMIT 1
        """, (sync_type,))
        return results[0] if results else None


class ConfigurationDAO:
    """Data Access Object for configuration table"""

    def __init__(self, db_manager: DatabaseManager):
        self.db = db_manager

    def get(self, key: str, default: str = None) -> Optional[str]:
        """Get configuration value"""
        results = self.db.execute_query(
            "SELECT value FROM configuration WHERE key = ?",
            (key,)
        )
        return results[0]['value'] if results else default

    def set(self, key: str, value: str):
        """Set configuration value (insert or update)"""
        with self.db.get_connection() as conn:
            cursor = conn.cursor()
            cursor.execute("""
                INSERT INTO configuration (key, value)
                VALUES (?, ?)
                ON CONFLICT(key) DO UPDATE SET
                    value = excluded.value,
                    updated_at = CURRENT_TIMESTAMP
            """, (key, value))
        logger.debug(f"Config updated: {key} = {value}")

    def get_all(self) -> Dict[str, str]:
        """Get all configurations as dictionary"""
        results = self.db.execute_query("SELECT key, value FROM configuration")
        return {row['key']: row['value'] for row in results}

    def get_int(self, key: str, default: int = 0) -> int:
        """Get configuration value as integer"""
        value = self.get(key)
        try:
            return int(value) if value else default
        except ValueError:
            logger.warning(f"Config value for {key} is not an integer: {value}")
            return default

    def increment(self, key: str) -> int:
        """Increment integer configuration value and return new value"""
        current = self.get_int(key, 0)
        new_value = current + 1
        self.set(key, str(new_value))
        return new_value
