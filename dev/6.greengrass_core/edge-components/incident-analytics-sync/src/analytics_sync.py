#!/usr/bin/env python3
"""
Incident Analytics Sync Service
Aggregates incident data from SQLite and publishes hourly summaries to AWS IoT Core

Component: com.aismc.IncidentAnalyticsSync v1.0.0
Architecture: v2.0 (Batch Analytics)
"""

import sys
import json
import time
import logging
import argparse
import sqlite3
from datetime import datetime, timedelta
from collections import Counter
from typing import Dict, List, Optional

# Add Greengrass IPC SDK
from awsiot.greengrasscoreipc.clientv2 import GreengrassCoreIPCClientV2
from awsiot.greengrasscoreipc.model import QOS

# Add DAO layer to path
sys.path.insert(0, '/greengrass/v2/components/common')

try:
    from database import DatabaseManager, IncidentDAO, DeviceDAO
except ImportError:
    logging.error("Failed to import database modules. Ensure common components are deployed.")
    sys.exit(1)

# Setup logging
logging.basicConfig(
    level=logging.INFO,
    format='%(asctime)s - %(name)s - %(levelname)s - %(message)s'
)
logger = logging.getLogger(__name__)


class IncidentAnalyticsSync:
    """
    Syncs incident analytics summaries to AWS IoT Core
    Runs continuously with configurable hourly intervals
    """

    def __init__(self, site_id: str, topic_prefix: str, top_count: int = 10):
        """
        Initialize analytics sync service

        Args:
            site_id: Site identifier (e.g., 'site-001')
            topic_prefix: MQTT topic prefix (e.g., 'aismc')
            top_count: Number of top affected devices to include
        """
        self.site_id = site_id
        self.topic_prefix = topic_prefix
        self.top_count = top_count

        # Initialize database
        self.db_manager = DatabaseManager()
        self.incident_dao = IncidentDAO(self.db_manager)
        self.device_dao = DeviceDAO(self.db_manager)

        # Initialize Greengrass IPC client
        try:
            self.ipc_client = GreengrassCoreIPCClientV2()
            logger.info("✅ Greengrass IPC client initialized")
        except Exception as e:
            logger.error(f"Failed to initialize IPC client: {e}")
            raise

        logger.info(f"Initialized IncidentAnalyticsSync for site: {site_id}")

    def aggregate_incidents(self, since_timestamp: int) -> Optional[Dict]:
        """
        Aggregate incidents from SQLite since given timestamp

        Args:
            since_timestamp: Unix timestamp

        Returns:
            Aggregated incident statistics or None if no incidents
        """
        try:
            # Query incidents since timestamp
            with self.db_manager.get_connection() as conn:
                cursor = conn.cursor()

                query = """
                    SELECT
                        camera_id as device_id,
                        severity,
                        incident_type,
                        'new' as status,
                        detected_at as timestamp
                    FROM incidents
                    WHERE detected_at >= ?
                    ORDER BY detected_at DESC
                """

                cursor.execute(query, (since_timestamp,))
                incidents = cursor.fetchall()

            if not incidents:
                logger.info(f"No incidents found since {datetime.fromtimestamp(since_timestamp)}")
                return None

            # Convert to list of dicts
            incident_list = []
            for row in incidents:
                incident_list.append({
                    'device_id': row[0],
                    'severity': row[1],
                    'incident_type': row[2],
                    'status': row[3],
                    'timestamp': row[4]
                })

            # Count by severity
            by_severity = Counter(i['severity'] for i in incident_list)

            # Count by incident type
            by_type = Counter(i['incident_type'] for i in incident_list)

            # Count by status
            by_status = Counter(i['status'] for i in incident_list)

            # Count by device (for top affected)
            device_counts = Counter(i['device_id'] for i in incident_list)
            top_devices = [
                {"device_id": dev_id, "incidents": count}
                for dev_id, count in device_counts.most_common(self.top_count)
            ]

            # Get device details for aggregation by type and group
            by_device_type = Counter()
            by_host_group = Counter()

            for incident in incident_list:
                device = self.device_dao.get_by_id(incident['device_id'])
                if device:
                    # Count by device type
                    device_type = device.get('device_type', 'unknown')
                    by_device_type[device_type] += 1

                    # Count by host groups (devices can be in multiple groups)
                    host_groups_str = device.get('host_groups', '')
                    if host_groups_str:
                        # Parse host group IDs and count
                        group_ids = host_groups_str.split(',')
                        for group_id in group_ids:
                            by_host_group[group_id] += 1

            return {
                "total": len(incident_list),
                "new": sum(1 for i in incident_list if i['status'] == 'new'),
                "recovered": sum(1 for i in incident_list if i['status'] == 'recovered'),
                "ongoing": sum(1 for i in incident_list if i['status'] == 'ongoing'),
                "by_severity": dict(by_severity),
                "by_device_type": dict(by_device_type),
                "by_incident_type": dict(by_type),
                "by_host_group": dict(by_host_group),
                "by_status": dict(by_status),
                "top_affected_devices": top_devices
            }

        except Exception as e:
            logger.error(f"Error aggregating incidents: {e}")
            return None

    def publish_summary(self, period_start: datetime, period_end: datetime):
        """
        Publish incident analytics summary to AWS IoT Core

        Args:
            period_start: Start of aggregation period
            period_end: End of aggregation period
        """
        try:
            since_timestamp = int(period_start.timestamp())

            # Aggregate incidents
            aggregates = self.aggregate_incidents(since_timestamp)

            if not aggregates:
                logger.info(f"No incidents in period {period_start} to {period_end}")
                # Still publish empty summary for monitoring
                aggregates = {
                    "total": 0,
                    "new": 0,
                    "recovered": 0,
                    "ongoing": 0,
                    "by_severity": {},
                    "by_device_type": {},
                    "by_incident_type": {},
                    "by_host_group": {},
                    "by_status": {},
                    "top_affected_devices": []
                }

            # Create summary message
            summary = {
                "type": "IncidentAnalyticsSummary",
                "site_id": self.site_id,
                "timestamp": period_end.isoformat() + "Z",
                "period": {
                    "start": period_start.isoformat() + "Z",
                    "end": period_end.isoformat() + "Z",
                    "duration_seconds": int((period_end - period_start).total_seconds())
                },
                "incidents": aggregates
            }

            # Publish to IoT Core
            topic = f"{self.topic_prefix}/{self.site_id}/analytics"
            payload = json.dumps(summary)

            self.ipc_client.publish_to_iot_core(
                topic_name=topic,
                qos=QOS.AT_LEAST_ONCE,
                payload=payload.encode('utf-8')
            )

            logger.info(f"✅ Published analytics summary to {topic}")
            logger.info(f"   Incidents: {aggregates['total']} (new: {aggregates['new']}, recovered: {aggregates['recovered']})")

        except Exception as e:
            logger.error(f"Error publishing summary: {e}")

    def run(self, interval: int):
        """
        Run continuous sync loop with specified interval

        Args:
            interval: Sync interval in seconds (e.g., 3600 for hourly)
        """
        logger.info("="*70)
        logger.info("  Incident Analytics Sync - Starting")
        logger.info(f"  Site ID: {self.site_id}")
        logger.info(f"  Interval: {interval}s ({interval/3600:.1f} hours)")
        logger.info("="*70)

        while True:
            try:
                now = datetime.utcnow()
                period_start = now - timedelta(seconds=interval)

                logger.info(f"Aggregating incidents from {period_start} to {now}")

                self.publish_summary(period_start, now)

                logger.info(f"Sleeping for {interval} seconds until next sync...")
                time.sleep(interval)

            except KeyboardInterrupt:
                logger.info("Received interrupt signal, shutting down...")
                sys.exit(0)
            except Exception as e:
                logger.error(f"Error in sync loop: {e}")
                logger.info(f"Sleeping for {interval} seconds before retry...")
                time.sleep(interval)


def main():
    """Main entry point"""
    parser = argparse.ArgumentParser(description='Incident Analytics Sync Service')
    parser.add_argument('--site-id', required=True, help='Site identifier')
    parser.add_argument('--interval', type=int, default=3600, help='Sync interval in seconds')
    parser.add_argument('--topic-prefix', default='aismc', help='MQTT topic prefix')
    parser.add_argument('--top-count', type=int, default=10, help='Number of top affected devices')

    args = parser.parse_args()

    # Create and run sync service
    sync = IncidentAnalyticsSync(
        site_id=args.site_id,
        topic_prefix=args.topic_prefix,
        top_count=args.top_count
    )

    sync.run(args.interval)


if __name__ == '__main__':
    main()
