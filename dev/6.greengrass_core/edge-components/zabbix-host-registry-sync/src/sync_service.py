#!/usr/bin/env python3
"""
Zabbix Host Registry Sync Service
Syncs ALL hosts and host groups from Zabbix to local SQLite database
Supports incremental sync using lastchange timestamp
Publishes daily inventory summary to AWS IoT Core (v2.0 architecture)

Component: com.aismc.ZabbixHostRegistrySync v1.0.0
"""
import sys
import json
import time
import logging
import requests
from datetime import datetime
from typing import Dict, List, Optional

# Add Greengrass IPC SDK
try:
    from awsiot.greengrasscoreipc.clientv2 import GreengrassCoreIPCClientV2
    from awsiot.greengrasscoreipc.model import QOS
    IPC_AVAILABLE = True
except ImportError:
    IPC_AVAILABLE = False
    logging.warning("Greengrass IPC SDK not available - cloud publishing disabled")

# Add DAO layer to path
sys.path.insert(0, '/greengrass/v2/components/common')

from database import DatabaseManager, DeviceDAO, HostGroupDAO, ConfigurationDAO, SyncLogDAO

# Setup logging
logging.basicConfig(
    level=logging.INFO,
    format='%(asctime)s - %(name)s - %(levelname)s - %(message)s'
)
logger = logging.getLogger(__name__)


class ZabbixAPIClient:
    """
    Zabbix API Client with Bearer token authentication
    Supports Zabbix 7.4+ API
    """

    def __init__(self, api_url: str, username: str, password: str):
        """
        Initialize Zabbix API client

        Args:
            api_url: Zabbix API endpoint URL
            username: Zabbix username
            password: Zabbix password
        """
        self.api_url = api_url
        self.username = username
        self.password = password
        self.auth_token = None
        self.session = requests.Session()
        self.session.headers.update({'Content-Type': 'application/json'})

    def authenticate(self) -> bool:
        """
        Authenticate with Zabbix API and get Bearer token

        Returns:
            True if successful, False otherwise
        """
        try:
            payload = {
                "jsonrpc": "2.0",
                "method": "user.login",
                "params": {
                    "username": self.username,
                    "password": self.password
                },
                "id": 1
            }

            response = self.session.post(self.api_url, json=payload, timeout=30)
            response.raise_for_status()
            result = response.json()

            if 'result' in result:
                self.auth_token = result['result']
                self.session.headers.update({'Authorization': f'Bearer {self.auth_token}'})
                logger.info("✅ Authenticated with Zabbix API")
                return True
            else:
                logger.error(f"Authentication failed: {result.get('error', 'Unknown error')}")
                return False

        except Exception as e:
            logger.error(f"Authentication error: {e}")
            return False

    def call_api(self, method: str, params: Dict = None) -> Optional[Dict]:
        """
        Call Zabbix API method

        Args:
            method: API method name (e.g., 'host.get')
            params: Method parameters

        Returns:
            API response result or None on error
        """
        if not self.auth_token:
            logger.error("Not authenticated - call authenticate() first")
            return None

        try:
            payload = {
                "jsonrpc": "2.0",
                "method": method,
                "params": params or {},
                "id": 1
            }

            response = self.session.post(self.api_url, json=payload, timeout=60)
            response.raise_for_status()
            result = response.json()

            if 'result' in result:
                return result['result']
            else:
                logger.error(f"API call failed: {result.get('error', 'Unknown error')}")
                return None

        except Exception as e:
            logger.error(f"API call error ({method}): {e}")
            return None

    def get_host_groups(self) -> List[Dict]:
        """Get all host groups"""
        return self.call_api('hostgroup.get', {
            'output': ['groupid', 'name', 'flags', 'uuid']
        }) or []

    def get_hosts(self, lastchange_since: int = None) -> List[Dict]:
        """
        Get all hosts, optionally filtered by lastchange timestamp

        Args:
            lastchange_since: Unix timestamp - only get hosts changed since this time

        Returns:
            List of host dictionaries
        """
        params = {
            'output': ['hostid', 'host', 'name', 'status', 'available',
                      'maintenance_status', 'lastaccess', 'ipmi_available'],
            'selectGroups': ['groupid', 'name'],
            'selectInterfaces': ['interfaceid', 'ip', 'port', 'type'],
            'selectTags': ['tag', 'value']
        }

        # Incremental sync - only changed hosts
        if lastchange_since:
            params['filter'] = {
                'lastchange': f'{lastchange_since}:'
            }
            logger.info(f"Fetching hosts changed since {lastchange_since} ({datetime.fromtimestamp(lastchange_since)})")
        else:
            logger.info("Fetching all hosts (full sync)")

        return self.call_api('host.get', params) or []


class ZabbixHostRegistrySync:
    """
    Syncs Zabbix host registry to local SQLite database
    Supports incremental sync and scheduled execution
    Publishes inventory summary to AWS IoT Core (v2.0)
    """

    def __init__(self, api_url: str, username: str, password: str,
                 incremental: bool = True, site_id: str = "site-001",
                 topic_prefix: str = "aismc", publish_to_cloud: bool = True):
        """
        Initialize sync service

        Args:
            api_url: Zabbix API endpoint
            username: Zabbix username
            password: Zabbix password
            incremental: Enable incremental sync (only changed hosts)
            site_id: Site identifier for cloud publishing
            topic_prefix: MQTT topic prefix
            publish_to_cloud: Enable cloud publishing (v2.0 feature)
        """
        self.api_url = api_url
        self.username = username
        self.password = password
        self.incremental = incremental
        self.site_id = site_id
        self.topic_prefix = topic_prefix
        self.publish_to_cloud = publish_to_cloud

        # Initialize database
        self.db_manager = DatabaseManager()
        self.device_dao = DeviceDAO(self.db_manager)
        self.hostgroup_dao = HostGroupDAO(self.db_manager)
        self.config_dao = ConfigurationDAO(self.db_manager)
        self.sync_log_dao = SyncLogDAO(self.db_manager)

        # Initialize Zabbix API client
        self.zabbix = ZabbixAPIClient(api_url, username, password)

        # Initialize Greengrass IPC client (v2.0 feature)
        self.ipc_client = None
        if publish_to_cloud and IPC_AVAILABLE:
            try:
                self.ipc_client = GreengrassCoreIPCClientV2()
                logger.info("✅ Greengrass IPC client initialized for cloud publishing")
            except Exception as e:
                logger.warning(f"Failed to initialize IPC client: {e}")
                self.publish_to_cloud = False

        logger.info(f"Initialized ZabbixHostRegistrySync")
        logger.info(f"API URL: {api_url}")
        logger.info(f"Incremental Sync: {incremental}")
        logger.info(f"Cloud Publishing: {self.publish_to_cloud}")

    def sync_host_groups(self) -> int:
        """
        Sync host groups from Zabbix to SQLite

        Returns:
            Number of host groups synced
        """
        try:
            logger.info("Syncing host groups...")
            groups = self.zabbix.get_host_groups()

            if not groups:
                logger.warning("No host groups found")
                return 0

            # Transform to DAO format
            groups_data = []
            for group in groups:
                groups_data.append({
                    'groupid': group['groupid'],
                    'name': group['name'],
                    'internal': int(group.get('internal', 0)),
                    'flags': int(group.get('flags', 0)),
                    'description': ''
                })

            # Batch upsert
            count = self.hostgroup_dao.batch_upsert(groups_data)
            logger.info(f"✅ Synced {count} host groups")

            # Update config
            self.config_dao.set('total_host_groups', str(count))

            return count

        except Exception as e:
            logger.error(f"Error syncing host groups: {e}")
            return 0

    def sync_hosts(self) -> Dict[str, int]:
        """
        Sync hosts from Zabbix to SQLite

        Returns:
            Statistics dict with counts
        """
        try:
            # Get last sync timestamp for incremental sync
            last_sync_unix = 0
            if self.incremental:
                last_sync_str = self.config_dao.get('last_sync_unix')
                if last_sync_str and last_sync_str != '0':
                    last_sync_unix = int(last_sync_str)

            logger.info("Syncing hosts...")
            hosts = self.zabbix.get_hosts(last_sync_unix if last_sync_unix > 0 else None)

            if not hosts:
                logger.info("No hosts to sync")
                return {'total': 0, 'new': 0, 'updated': 0}

            # Transform to device format
            devices_data = []
            for host in hosts:
                # Get primary IP from interfaces
                ip_address = None
                port = '10050'
                if host.get('interfaces'):
                    primary_interface = host['interfaces'][0]
                    ip_address = primary_interface.get('ip')
                    port = primary_interface.get('port', '10050')

                # Determine device type from host groups
                device_type = 'unknown'
                host_groups_str = ''
                if host.get('groups'):
                    group_names = [g['name'].lower() for g in host['groups']]
                    host_groups_str = ','.join([g['groupid'] for g in host['groups']])

                    # Classify device type
                    if any('camera' in name for name in group_names):
                        device_type = 'camera'
                    elif any('server' in name for name in group_names):
                        device_type = 'server'
                    elif any('network' in name or 'switch' in name or 'router' in name for name in group_names):
                        device_type = 'network'

                # Map Zabbix status to our status
                status_map = {
                    '0': 'online',   # Monitored
                    '1': 'offline'   # Not monitored
                }
                status = status_map.get(host.get('status', '1'), 'unknown')

                # Create device record
                device_id = f"DEV-{host['hostid']}"
                device = {
                    'device_id': device_id,
                    'zabbix_host_id': host['hostid'],
                    'host_name': host['host'],
                    'visible_name': host.get('name', host['host']),
                    'device_type': device_type,
                    'ip_address': ip_address,
                    'port': port,
                    'status': status,
                    'available': int(host.get('available', 0)),
                    'maintenance_status': int(host.get('maintenance_status', 0)),
                    'lastchange': int(time.time()),  # Current time as lastchange
                    'host_groups': host_groups_str,
                    'tags': host.get('tags', []),
                    'ngsi_ld': self._create_ngsi_ld(device_id, host, device_type)
                }

                devices_data.append(device)

            # Batch upsert devices
            count = self.device_dao.batch_upsert(devices_data)
            logger.info(f"✅ Synced {count} devices")

            # Update config
            total_devices = self.device_dao.get_count()
            self.config_dao.set('total_devices', str(total_devices))
            self.config_dao.set('last_sync_timestamp', datetime.utcnow().isoformat() + 'Z')
            self.config_dao.set('last_sync_unix', str(int(time.time())))

            return {
                'total': count,
                'new': count,  # Simplified - would need to track this separately
                'updated': 0
            }

        except Exception as e:
            logger.error(f"Error syncing hosts: {e}")
            return {'total': 0, 'new': 0, 'updated': 0, 'error': str(e)}

    def _create_ngsi_ld(self, device_id: str, host: Dict, device_type: str) -> Dict:
        """Create NGSI-LD representation of device"""
        return {
            '@context': 'https://uri.etsi.org/ngsi-ld/v1/ngsi-ld-core-context.jsonld',
            'id': f'urn:ngsi-ld:Device:{device_id}',
            'type': 'Device',
            'name': {
                'type': 'Property',
                'value': host.get('name', host['host'])
            },
            'deviceType': {
                'type': 'Property',
                'value': device_type
            },
            'zabbixHostId': {
                'type': 'Property',
                'value': host['hostid']
            }
        }

    def publish_inventory_summary(self):
        """
        Publish device inventory summary to AWS IoT Core (v2.0 feature)
        Topic: aismc/{site_id}/inventory
        """
        if not self.publish_to_cloud or not self.ipc_client:
            logger.debug("Cloud publishing disabled, skipping inventory summary")
            return

        try:
            # Get total device count
            total_devices = self.device_dao.get_count()

            # Get count by device type
            by_device_type = self.device_dao.get_count_by_type()

            # Get count by status
            by_status = self.device_dao.get_count_by_status()

            # Get count by host group
            conn = self.db_manager.get_connection()
            cursor = conn.cursor()

            # Query device counts by host group
            query = """
                SELECT hg.name, COUNT(d.device_id) as count
                FROM host_groups hg
                LEFT JOIN devices d ON (',' || d.host_groups || ',') LIKE ('%,' || hg.groupid || ',%')
                GROUP BY hg.groupid, hg.name
                HAVING count > 0
                ORDER BY count DESC
            """
            cursor.execute(query)
            by_host_group = {row[0]: row[1] for row in cursor.fetchall()}

            # Create inventory summary
            summary = {
                "type": "DeviceInventorySummary",
                "site_id": self.site_id,
                "timestamp": datetime.utcnow().isoformat() + "Z",
                "period": "daily",
                "summary": {
                    "total_devices": total_devices,
                    "by_host_group": by_host_group,
                    "by_device_type": by_device_type,
                    "by_status": by_status
                }
            }

            # Publish to IoT Core
            topic = f"{self.topic_prefix}/{self.site_id}/inventory"
            payload = json.dumps(summary)

            self.ipc_client.publish_to_iot_core(
                topic_name=topic,
                qos=QOS.AT_LEAST_ONCE,
                payload=payload.encode('utf-8')
            )

            logger.info(f"✅ Published inventory summary to {topic}")
            logger.info(f"   Total devices: {total_devices}")

        except Exception as e:
            logger.error(f"Error publishing inventory summary: {e}")

    def run_sync(self) -> bool:
        """
        Execute full sync cycle

        Returns:
            True if successful, False otherwise
        """
        start_time = time.time()
        logger.info("="*70)
        logger.info("  Zabbix Host Registry Sync - Starting")
        logger.info("="*70)

        try:
            # Authenticate
            if not self.zabbix.authenticate():
                logger.error("❌ Authentication failed - aborting sync")
                return False

            # Sync host groups
            groups_count = self.sync_host_groups()

            # Sync hosts
            hosts_stats = self.sync_hosts()

            # Calculate duration
            duration_ms = int((time.time() - start_time) * 1000)

            # Log sync
            self.sync_log_dao.log(
                sync_type='host_registry',
                records_synced=hosts_stats.get('total', 0),
                status='success',
                duration_ms=duration_ms
            )

            # Publish inventory summary to cloud (v2.0 feature)
            self.publish_inventory_summary()

            logger.info("="*70)
            logger.info("  Sync Complete")
            logger.info(f"  Host Groups: {groups_count}")
            logger.info(f"  Devices: {hosts_stats.get('total', 0)}")
            logger.info(f"  Duration: {duration_ms}ms")
            logger.info("="*70)

            return True

        except Exception as e:
            duration_ms = int((time.time() - start_time) * 1000)
            logger.error(f"Sync failed: {e}")

            self.sync_log_dao.log(
                sync_type='host_registry',
                records_synced=0,
                status='error',
                error_message=str(e),
                duration_ms=duration_ms
            )

            return False


def main():
    """Main entry point"""
    import argparse

    parser = argparse.ArgumentParser(description='Zabbix Host Registry Sync Service')
    parser.add_argument('--api-url', required=True, help='Zabbix API URL')
    parser.add_argument('--username', required=True, help='Zabbix username')
    parser.add_argument('--password', required=True, help='Zabbix password')
    parser.add_argument('--incremental', action='store_true', default=True,
                       help='Enable incremental sync')
    parser.add_argument('--full', action='store_true',
                       help='Force full sync (ignore lastchange)')
    parser.add_argument('--schedule', type=int, default=0,
                       help='Run continuously with interval in seconds (0=run once)')
    parser.add_argument('--site-id', default='site-001',
                       help='Site identifier for cloud publishing')
    parser.add_argument('--topic-prefix', default='aismc',
                       help='MQTT topic prefix')
    parser.add_argument('--no-cloud-publish', action='store_true',
                       help='Disable cloud publishing (v2.0 feature)')

    args = parser.parse_args()

    # Create sync service
    sync = ZabbixHostRegistrySync(
        api_url=args.api_url,
        username=args.username,
        password=args.password,
        incremental=not args.full,
        site_id=args.site_id,
        topic_prefix=args.topic_prefix,
        publish_to_cloud=not args.no_cloud_publish
    )

    # Run once or continuously based on schedule
    if args.schedule > 0:
        logger.info(f"Running in scheduled mode: every {args.schedule} seconds")
        while True:
            try:
                success = sync.run_sync()
                if not success:
                    logger.warning("Sync failed, will retry at next interval")

                logger.info(f"Sleeping for {args.schedule} seconds until next sync...")
                time.sleep(args.schedule)
            except KeyboardInterrupt:
                logger.info("Received interrupt signal, shutting down...")
                sys.exit(0)
            except Exception as e:
                logger.error(f"Unexpected error: {e}")
                logger.info(f"Sleeping for {args.schedule} seconds before retry...")
                time.sleep(args.schedule)
    else:
        # Run once and exit
        success = sync.run_sync()
        sys.exit(0 if success else 1)


if __name__ == '__main__':
    main()
