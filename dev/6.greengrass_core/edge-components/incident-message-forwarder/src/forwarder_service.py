#!/usr/bin/env python3
"""
Incident Message Forwarder Service
Forwards incidents from local SQLite to AWS IoT Core via MQTT
Provides offline resilience with retry logic

Component: com.aismc.IncidentMessageForwarder v1.0.0
"""
import sys
import json
import time
import logging
from datetime import datetime
from typing import Dict, List, Optional

# Add DAO layer to path
sys.path.insert(0, '/greengrass/v2/components/common')

from database import DatabaseManager, IncidentDAO, MessageQueueDAO, ConfigurationDAO
from database import CameraDAO, DeviceDAO

# Greengrass IPC for MQTT publish and Shadow update
try:
    import awsiot.greengrasscoreipc
    import awsiot.greengrasscoreipc.client as client
    from awsiot.greengrasscoreipc.model import (
        PublishToIoTCoreRequest,
        QOS,
        UpdateThingShadowRequest
    )
    GREENGRASS_AVAILABLE = True
except ImportError:
    GREENGRASS_AVAILABLE = False
    logging.warning("Greengrass IPC not available - running in standalone mode")

# Setup logging
logging.basicConfig(
    level=logging.INFO,
    format='%(asctime)s - %(name)s - %(levelname)s - %(message)s'
)
logger = logging.getLogger(__name__)


class IncidentMessageForwarder:
    """
    Forwards incidents from SQLite message queue to AWS IoT Core
    Handles retry logic and offline resilience
    """

    def __init__(self, site_id: str = "site-001", poll_interval: int = 10):
        """
        Initialize the forwarder service

        Args:
            site_id: Site identifier for MQTT topic routing
            poll_interval: Seconds between queue polls
        """
        self.site_id = site_id
        self.poll_interval = poll_interval
        self.max_retries = 5
        self.batch_size = 10

        # Initialize database
        self.db_manager = DatabaseManager()
        self.incident_dao = IncidentDAO(self.db_manager)
        self.message_queue_dao = MessageQueueDAO(self.db_manager)
        self.config_dao = ConfigurationDAO(self.db_manager)
        self.camera_dao = CameraDAO(self.db_manager)
        self.device_dao = DeviceDAO(self.db_manager)

        # Get site_id from config if available
        configured_site_id = self.config_dao.get('site_id')
        if configured_site_id:
            self.site_id = configured_site_id

        # MQTT topic for incidents
        self.incident_topic = f"aismc/incidents/{self.site_id}"
        self.shadow_topic = f"$aws/things/GreengrassCore-{self.site_id}-hanoi/shadow/update"

        # Initialize Greengrass IPC client
        self.ipc_client = None
        if GREENGRASS_AVAILABLE:
            try:
                self.ipc_client = awsiot.greengrasscoreipc.connect()
                logger.info("✅ Connected to Greengrass IPC")
            except Exception as e:
                logger.error(f"Failed to connect to Greengrass IPC: {e}")
                self.ipc_client = None

        logger.info(f"Initialized IncidentMessageForwarder for site: {self.site_id}")
        logger.info(f"MQTT Topic: {self.incident_topic}")
        logger.info(f"Poll interval: {self.poll_interval}s")

    def publish_to_iot_core(self, topic: str, payload: Dict) -> bool:
        """
        Publish message to AWS IoT Core via MQTT

        Args:
            topic: MQTT topic
            payload: Message payload (will be JSON encoded)

        Returns:
            True if successful, False otherwise
        """
        if not self.ipc_client:
            logger.warning("IPC client not available - cannot publish")
            return False

        try:
            request = PublishToIoTCoreRequest()
            request.topic_name = topic
            request.payload = json.dumps(payload).encode('utf-8')
            request.qos = QOS.AT_LEAST_ONCE

            operation = self.ipc_client.new_publish_to_iot_core()
            operation.activate(request)
            future = operation.get_response()
            future.result(timeout=5.0)

            logger.info(f"✅ Published to IoT Core: {topic}")
            return True

        except Exception as e:
            logger.error(f"Failed to publish to IoT Core: {e}")
            return False

    def update_shadow(self, device_id: str, state: Dict) -> bool:
        """
        Update Device Shadow with reported state

        Args:
            device_id: Device identifier
            state: State to report

        Returns:
            True if successful, False otherwise
        """
        if not self.ipc_client:
            logger.warning("IPC client not available - cannot update shadow")
            return False

        try:
            shadow_payload = {
                "state": {
                    "reported": state
                }
            }

            request = UpdateThingShadowRequest()
            request.thing_name = f"GreengrassCore-{self.site_id}-hanoi"
            request.shadow_name = device_id
            request.payload = json.dumps(shadow_payload).encode('utf-8')

            operation = self.ipc_client.new_update_thing_shadow()
            operation.activate(request)
            future = operation.get_response()
            future.result(timeout=5.0)

            logger.info(f"✅ Updated shadow for device: {device_id}")
            return True

        except Exception as e:
            logger.error(f"Failed to update shadow: {e}")
            return False

    def process_pending_messages(self) -> int:
        """
        Process pending messages from queue

        Returns:
            Number of messages successfully processed
        """
        try:
            # Get pending messages
            pending = self.message_queue_dao.get_pending(limit=self.batch_size)

            if not pending:
                return 0

            logger.info(f"Processing {len(pending)} pending messages...")

            processed = 0
            for msg in pending:
                # Check retry limit
                if msg['retry_count'] >= self.max_retries:
                    logger.warning(f"Message {msg['message_id']} exceeded max retries - skipping")
                    continue

                try:
                    # Parse payload
                    payload = json.loads(msg['payload'])

                    # Publish to MQTT
                    success = self.publish_to_iot_core(msg['topic'], payload)

                    if success:
                        # Mark as sent
                        self.message_queue_dao.mark_sent(msg['message_id'])

                        # Update shadow if device_id present
                        if 'device_id' in payload:
                            device_state = {
                                "last_incident": payload.get('incident_id'),
                                "last_update": datetime.utcnow().isoformat() + 'Z',
                                "status": payload.get('status', 'unknown')
                            }
                            self.update_shadow(payload['device_id'], device_state)

                        processed += 1
                        logger.info(f"✅ Processed message {msg['message_id']}")

                    else:
                        # Increment retry count
                        self.message_queue_dao.increment_attempt(msg['message_id'])
                        logger.warning(f"Failed to publish message {msg['message_id']} - will retry")

                except Exception as e:
                    logger.error(f"Error processing message {msg['message_id']}: {e}")
                    self.message_queue_dao.increment_attempt(msg['message_id'])

            return processed

        except Exception as e:
            logger.error(f"Error in process_pending_messages: {e}")
            return 0

    def get_statistics(self) -> Dict:
        """Get forwarder statistics"""
        try:
            pending = self.message_queue_dao.get_pending_count()
            failed = self.message_queue_dao.get_failed_count(self.max_retries)

            return {
                "pending_messages": pending,
                "failed_messages": failed,
                "max_retries": self.max_retries,
                "poll_interval": self.poll_interval,
                "site_id": self.site_id,
                "ipc_connected": self.ipc_client is not None
            }
        except Exception as e:
            logger.error(f"Error getting statistics: {e}")
            return {}

    def run(self):
        """
        Main service loop - poll and process messages
        """
        logger.info("="*70)
        logger.info("  Incident Message Forwarder Service")
        logger.info("="*70)
        logger.info(f"  Site ID: {self.site_id}")
        logger.info(f"  MQTT Topic: {self.incident_topic}")
        logger.info(f"  Poll Interval: {self.poll_interval}s")
        logger.info(f"  Batch Size: {self.batch_size}")
        logger.info(f"  Max Retries: {self.max_retries}")
        logger.info(f"  IPC Connected: {self.ipc_client is not None}")
        logger.info("="*70)

        iteration = 0
        while True:
            try:
                iteration += 1

                # Process pending messages
                processed = self.process_pending_messages()

                # Log statistics every 10 iterations
                if iteration % 10 == 0:
                    stats = self.get_statistics()
                    logger.info(f"Statistics: {json.dumps(stats, indent=2)}")

                # Wait before next poll
                time.sleep(self.poll_interval)

            except KeyboardInterrupt:
                logger.info("Shutting down gracefully...")
                break
            except Exception as e:
                logger.error(f"Error in main loop: {e}")
                time.sleep(self.poll_interval)


def main():
    """Main entry point"""
    import argparse

    parser = argparse.ArgumentParser(description='Incident Message Forwarder Service')
    parser.add_argument('--site-id', default='site-001', help='Site identifier')
    parser.add_argument('--poll-interval', type=int, default=10, help='Poll interval in seconds')
    parser.add_argument('--batch-size', type=int, default=10, help='Batch size for processing')

    args = parser.parse_args()

    # Create and run forwarder
    forwarder = IncidentMessageForwarder(
        site_id=args.site_id,
        poll_interval=args.poll_interval
    )
    forwarder.batch_size = args.batch_size

    forwarder.run()


if __name__ == '__main__':
    main()
