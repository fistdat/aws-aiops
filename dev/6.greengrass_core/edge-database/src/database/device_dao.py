"""
Device DAO - Data Access Object for devices table (ALL Zabbix hosts)
Generalized DAO for cameras, servers, network devices, etc.
"""
import json
import logging
from datetime import datetime
from typing import List, Dict, Optional
from .connection import DatabaseManager

logger = logging.getLogger(__name__)


class DeviceDAO:
    """Data Access Object for devices table"""

    def __init__(self, db_manager: DatabaseManager):
        self.db = db_manager

    def insert(self, device: Dict) -> str:
        """
        Insert a new device

        Args:
            device: Dictionary with device attributes

        Returns:
            device_id of inserted device
        """
        with self.db.get_connection() as conn:
            cursor = conn.cursor()
            cursor.execute("""
                INSERT INTO devices (
                    device_id, zabbix_host_id, host_name, visible_name, device_type,
                    ip_address, port, status, available, maintenance_status, lastchange,
                    host_groups, location, tags, ngsi_ld_json
                ) VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?)
            """, (
                device['device_id'],
                device['zabbix_host_id'],
                device['host_name'],
                device.get('visible_name', device['host_name']),
                device.get('device_type', 'unknown'),
                device.get('ip_address'),
                device.get('port', '10050'),
                device.get('status', 'unknown'),
                device.get('available', 0),
                device.get('maintenance_status', 0),
                device.get('lastchange'),
                device.get('host_groups', ''),
                device.get('location'),
                json.dumps(device.get('tags', [])),
                json.dumps(device['ngsi_ld'])
            ))
        logger.info(f"Inserted device: {device['device_id']} ({device.get('device_type')})")
        return device['device_id']

    def batch_upsert(self, devices: List[Dict]) -> int:
        """
        Batch insert/update devices (efficient for large datasets)

        Args:
            devices: List of device dictionaries

        Returns:
            Number of devices processed
        """
        count = 0
        with self.db.get_connection() as conn:
            cursor = conn.cursor()
            for device in devices:
                cursor.execute("""
                    INSERT INTO devices (
                        device_id, zabbix_host_id, host_name, visible_name, device_type,
                        ip_address, port, status, available, maintenance_status, lastchange,
                        host_groups, location, tags, ngsi_ld_json
                    ) VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?)
                    ON CONFLICT(device_id) DO UPDATE SET
                        host_name = excluded.host_name,
                        visible_name = excluded.visible_name,
                        ip_address = excluded.ip_address,
                        port = excluded.port,
                        status = excluded.status,
                        available = excluded.available,
                        maintenance_status = excluded.maintenance_status,
                        lastchange = excluded.lastchange,
                        host_groups = excluded.host_groups,
                        location = excluded.location,
                        tags = excluded.tags,
                        ngsi_ld_json = excluded.ngsi_ld_json,
                        last_seen = CURRENT_TIMESTAMP,
                        updated_at = CURRENT_TIMESTAMP
                """, (
                    device['device_id'],
                    device['zabbix_host_id'],
                    device['host_name'],
                    device.get('visible_name', device['host_name']),
                    device.get('device_type', 'unknown'),
                    device.get('ip_address'),
                    device.get('port', '10050'),
                    device.get('status', 'unknown'),
                    device.get('available', 0),
                    device.get('maintenance_status', 0),
                    device.get('lastchange'),
                    device.get('host_groups', ''),
                    device.get('location'),
                    json.dumps(device.get('tags', [])),
                    json.dumps(device['ngsi_ld'])
                ))
                count += 1
        logger.info(f"Batch upserted {count} devices")
        return count

    def get_by_id(self, device_id: str) -> Optional[Dict]:
        """Get device by device_id"""
        results = self.db.execute_query(
            "SELECT * FROM devices WHERE device_id = ?",
            (device_id,)
        )
        return results[0] if results else None

    def get_by_zabbix_host_id(self, zabbix_host_id: str) -> Optional[Dict]:
        """Get device by Zabbix host ID"""
        results = self.db.execute_query(
            "SELECT * FROM devices WHERE zabbix_host_id = ?",
            (zabbix_host_id,)
        )
        return results[0] if results else None

    def get_all(self, device_type: str = None, status: str = None) -> List[Dict]:
        """
        Get all devices with optional filters

        Args:
            device_type: Filter by device type (camera, server, network, etc.)
            status: Filter by status (online/offline/unknown)

        Returns:
            List of device dictionaries
        """
        query = "SELECT * FROM devices WHERE 1=1"
        params = []

        if device_type:
            query += " AND device_type = ?"
            params.append(device_type)

        if status:
            query += " AND status = ?"
            params.append(status)

        query += " ORDER BY updated_at DESC"
        return self.db.execute_query(query, tuple(params))

    def get_by_type(self, device_type: str) -> List[Dict]:
        """Get all devices of a specific type"""
        return self.get_all(device_type=device_type)

    def update_status(self, device_id: str, status: str, available: int = None):
        """Update device status and availability"""
        if available is not None:
            self.db.execute_update(
                "UPDATE devices SET status = ?, available = ?, last_seen = CURRENT_TIMESTAMP WHERE device_id = ?",
                (status, available, device_id)
            )
        else:
            self.db.execute_update(
                "UPDATE devices SET status = ?, last_seen = CURRENT_TIMESTAMP WHERE device_id = ?",
                (status, device_id)
            )
        logger.info(f"Updated device {device_id} status to {status}")

    def get_count(self, device_type: str = None) -> int:
        """Get total device count, optionally filtered by type"""
        if device_type:
            result = self.db.execute_query(
                "SELECT COUNT(*) as count FROM devices WHERE device_type = ?",
                (device_type,)
            )
        else:
            result = self.db.execute_query("SELECT COUNT(*) as count FROM devices")
        return result[0]['count']

    def get_modified_since(self, unix_timestamp: int) -> List[Dict]:
        """
        Get devices modified since given Unix timestamp
        Used for incremental sync

        Args:
            unix_timestamp: Unix timestamp to compare against lastchange

        Returns:
            List of devices modified after timestamp
        """
        return self.db.execute_query("""
            SELECT * FROM devices
            WHERE lastchange > ?
            ORDER BY lastchange DESC
        """, (unix_timestamp,))

    def mark_as_deleted(self, device_ids: List[str]):
        """Mark devices as deleted (soft delete)"""
        if not device_ids:
            return

        with self.db.get_connection() as conn:
            cursor = conn.cursor()
            placeholders = ','.join('?' * len(device_ids))
            cursor.execute(f"""
                UPDATE devices
                SET status = 'deleted', updated_at = CURRENT_TIMESTAMP
                WHERE device_id IN ({placeholders})
            """, device_ids)
        logger.info(f"Marked {len(device_ids)} devices as deleted")


class HostGroupDAO:
    """Data Access Object for host_groups table"""

    def __init__(self, db_manager: DatabaseManager):
        self.db = db_manager

    def insert(self, host_group: Dict) -> str:
        """Insert a new host group"""
        with self.db.get_connection() as conn:
            cursor = conn.cursor()
            cursor.execute("""
                INSERT INTO host_groups (
                    groupid, name, description, internal, flags
                ) VALUES (?, ?, ?, ?, ?)
            """, (
                host_group['groupid'],
                host_group['name'],
                host_group.get('description', ''),
                host_group.get('internal', 0),
                host_group.get('flags', 0)
            ))
        logger.info(f"Inserted host group: {host_group['name']}")
        return host_group['groupid']

    def batch_upsert(self, host_groups: List[Dict]) -> int:
        """Batch insert/update host groups"""
        count = 0
        with self.db.get_connection() as conn:
            cursor = conn.cursor()
            for hg in host_groups:
                cursor.execute("""
                    INSERT INTO host_groups (
                        groupid, name, description, internal, flags
                    ) VALUES (?, ?, ?, ?, ?)
                    ON CONFLICT(groupid) DO UPDATE SET
                        name = excluded.name,
                        description = excluded.description,
                        internal = excluded.internal,
                        flags = excluded.flags,
                        updated_at = CURRENT_TIMESTAMP
                """, (
                    hg['groupid'],
                    hg['name'],
                    hg.get('description', ''),
                    hg.get('internal', 0),
                    hg.get('flags', 0)
                ))
                count += 1
        logger.info(f"Batch upserted {count} host groups")
        return count

    def get_by_id(self, groupid: str) -> Optional[Dict]:
        """Get host group by ID"""
        results = self.db.execute_query(
            "SELECT * FROM host_groups WHERE groupid = ?",
            (groupid,)
        )
        return results[0] if results else None

    def get_by_name(self, name: str) -> Optional[Dict]:
        """Get host group by name"""
        results = self.db.execute_query(
            "SELECT * FROM host_groups WHERE name = ?",
            (name,)
        )
        return results[0] if results else None

    def get_all(self) -> List[Dict]:
        """Get all host groups"""
        return self.db.execute_query(
            "SELECT * FROM host_groups ORDER BY name"
        )

    def get_count(self) -> int:
        """Get total host group count"""
        result = self.db.execute_query("SELECT COUNT(*) as count FROM host_groups")
        return result[0]['count']
