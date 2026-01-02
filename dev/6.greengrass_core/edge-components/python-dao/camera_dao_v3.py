"""
CameraDAO v3.0 - Backward Compatible Wrapper for DeviceDAO
Migration: cameras table → devices table with device_type='camera'

This module provides backward compatibility for existing code while
internally using the unified DeviceDAO for all operations.
"""
import json
import logging
from datetime import datetime
from typing import List, Dict, Optional

try:
    from .device_dao import DeviceDAO
    from .connection import DatabaseManager
except ImportError:
    from device_dao import DeviceDAO
    from connection import DatabaseManager

logger = logging.getLogger(__name__)


class CameraDAO:
    """
    Backward-compatible CameraDAO wrapper around DeviceDAO.

    All operations automatically filter for device_type='camera'.
    Maintains same API as legacy CameraDAO but uses unified devices table.

    Migration Status: v3.0 - cameras table replaced with VIEW
    """

    def __init__(self, db_manager: DatabaseManager):
        """Initialize CameraDAO with DeviceDAO backend"""
        self.db = db_manager
        self._device_dao = DeviceDAO(db_manager)
        self._device_type = 'camera'
        logger.debug("CameraDAO initialized with DeviceDAO backend (v3.0)")

    def insert(self, camera: Dict) -> str:
        """
        Insert a new camera (inserts into devices table)

        Args:
            camera: Dictionary with camera data
                Required: camera_id, zabbix_host_id, ip_address
                Optional: hostname, location, site_id, model, firmware_version, status, ngsi_ld

        Returns:
            camera_id of inserted camera
        """
        # Transform camera dict to device dict
        device = {
            'device_id': camera['camera_id'],
            'zabbix_host_id': camera['zabbix_host_id'],
            'host_name': camera.get('hostname', camera['camera_id']),
            'visible_name': camera.get('hostname', camera['camera_id']),
            'device_type': self._device_type,
            'ip_address': camera['ip_address'],
            'port': camera.get('port', '10050'),
            'status': camera.get('status', 'unknown'),
            'location': camera.get('location'),
            'site_id': camera.get('site_id', 'site-001'),
            'model': camera.get('model'),
            'firmware_version': camera.get('firmware_version'),
            'ngsi_ld_json': json.dumps(camera.get('ngsi_ld', {}))
        }

        device_id = self._device_dao.insert(device)
        logger.info(f"Inserted camera via DeviceDAO: {device_id}")
        return device_id

    def batch_upsert(self, cameras: List[Dict]) -> int:
        """
        Batch insert/update cameras

        Args:
            cameras: List of camera dictionaries

        Returns:
            Number of cameras processed
        """
        devices = []
        for camera in cameras:
            device = {
                'device_id': camera['camera_id'],
                'zabbix_host_id': camera['zabbix_host_id'],
                'host_name': camera.get('hostname', camera['camera_id']),
                'visible_name': camera.get('hostname', camera['camera_id']),
                'device_type': self._device_type,
                'ip_address': camera['ip_address'],
                'port': camera.get('port', '10050'),
                'status': camera.get('status', 'unknown'),
                'location': camera.get('location'),
                'site_id': camera.get('site_id', 'site-001'),
                'model': camera.get('model'),
                'firmware_version': camera.get('firmware_version'),
                'ngsi_ld_json': json.dumps(camera.get('ngsi_ld', {}))
            }
            devices.append(device)

        count = self._device_dao.batch_upsert(devices)
        logger.info(f"Batch upserted {count} cameras via DeviceDAO")
        return count

    def get_by_id(self, camera_id: str) -> Optional[Dict]:
        """
        Get camera by ID

        Args:
            camera_id: Camera ID

        Returns:
            Camera dict or None if not found
        """
        device = self._device_dao.get_by_id(camera_id)
        if device and device['device_type'] == self._device_type:
            return self._device_to_camera(device)
        return None

    def get_by_zabbix_host_id(self, zabbix_host_id: str) -> Optional[Dict]:
        """Get camera by Zabbix host ID"""
        device = self._device_dao.get_by_zabbix_host_id(zabbix_host_id)
        if device and device['device_type'] == self._device_type:
            return self._device_to_camera(device)
        return None

    def get_by_ip(self, ip_address: str) -> Optional[Dict]:
        """Get camera by IP address"""
        device = self._device_dao.get_by_ip(ip_address)
        if device and device['device_type'] == self._device_type:
            return self._device_to_camera(device)
        return None

    def get_all(self, site_id: str = None, status: str = None) -> List[Dict]:
        """
        Get all cameras with optional filters

        Args:
            site_id: Filter by site ID
            status: Filter by status (online/offline/unknown)

        Returns:
            List of camera dictionaries
        """
        devices = self._device_dao.get_all(
            device_type=self._device_type,
            site_id=site_id,
            status=status
        )
        return [self._device_to_camera(d) for d in devices]

    def get_offline_cameras(self, site_id: str = None) -> List[Dict]:
        """Get all offline cameras"""
        return self.get_all(site_id=site_id, status='offline')

    def update_status(self, camera_id: str, status: str):
        """
        Update camera status

        Args:
            camera_id: Camera ID
            status: New status (online/offline/unknown)
        """
        self._device_dao.update_status(camera_id, status)
        logger.info(f"Updated camera {camera_id} status to {status} via DeviceDAO")

    def get_count(self, status: str = None) -> int:
        """
        Get camera count

        Args:
            status: Optional status filter

        Returns:
            Number of cameras
        """
        return self._device_dao.get_count(device_type=self._device_type, status=status)

    def _device_to_camera(self, device: Dict) -> Dict:
        """
        Transform device dict to legacy camera dict format

        Args:
            device: Device dictionary from DeviceDAO

        Returns:
            Camera dictionary in legacy format
        """
        return {
            'camera_id': device['device_id'],
            'zabbix_host_id': device['zabbix_host_id'],
            'ip_address': device['ip_address'],
            'hostname': device['host_name'],
            'location': device.get('location'),
            'site_id': device.get('site_id', 'site-001'),
            'device_type': device.get('device_type', 'IP_Camera'),
            'model': device.get('model'),
            'firmware_version': device.get('firmware_version'),
            'status': device['status'],
            'last_seen': device.get('last_seen'),
            'ngsi_ld_json': device.get('ngsi_ld_json'),
            'created_at': device.get('created_at'),
            'updated_at': device.get('updated_at')
        }
