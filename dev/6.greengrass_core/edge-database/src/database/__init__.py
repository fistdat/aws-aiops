"""
Edge Database Layer for AWS IoT Greengrass
Version: 1.0.0
Purpose: Provide data access layer for local SQLite database
"""

from .connection import DatabaseManager
from .dao import (
    CameraDAO,
    IncidentDAO,
    MessageQueueDAO,
    SyncLogDAO,
    ConfigurationDAO
)
from .device_dao import DeviceDAO, HostGroupDAO

__version__ = "1.0.0"
__all__ = [
    "DatabaseManager",
    "CameraDAO",
    "IncidentDAO",
    "MessageQueueDAO",
    "SyncLogDAO",
    "ConfigurationDAO",
    "DeviceDAO",
    "HostGroupDAO"
]
