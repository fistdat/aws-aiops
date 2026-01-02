#!/usr/bin/env python3
"""
Zabbix Event Subscriber - Webhook HTTP Server
Receives Zabbix problem/recovery notifications via webhook
Stores incidents in local SQLite database

Component: com.aismc.ZabbixEventSubscriber v1.0.0
"""
import sys
import json
import logging
from datetime import datetime
from uuid import uuid4
from flask import Flask, request, jsonify

# Add DAO layer to path
sys.path.insert(0, '/greengrass/v2/components/common')

from database.connection import DatabaseManager
from database.dao import IncidentDAO, CameraDAO, ConfigurationDAO
from utils.ngsi_ld import transform_zabbix_webhook_to_incident, transform_incident_to_ngsi_ld

# Setup logging
logging.basicConfig(
    level=logging.INFO,
    format='%(asctime)s - %(name)s - %(levelname)s - %(message)s'
)
logger = logging.getLogger(__name__)

# Initialize Flask app
app = Flask(__name__)

# Initialize Database
db_manager = DatabaseManager()
incident_dao = IncidentDAO(db_manager)
camera_dao = CameraDAO(db_manager)
config_dao = ConfigurationDAO(db_manager)

# Get site_id from configuration
SITE_ID = config_dao.get('site_id') or 'site-001'
logger.info(f"Initialized ZabbixEventSubscriber for site: {SITE_ID}")


@app.route('/health', methods=['GET'])
def health_check():
    """Health check endpoint"""
    try:
        health = db_manager.health_check()
        return jsonify({
            'status': 'healthy',
            'component': 'ZabbixEventSubscriber',
            'version': '1.0.0',
            'database': health
        }), 200
    except Exception as e:
        logger.error(f"Health check failed: {e}")
        return jsonify({
            'status': 'unhealthy',
            'error': str(e)
        }), 500


@app.route('/zabbix/events', methods=['POST'])
def receive_zabbix_event():
    """
    Receive Zabbix webhook event (problem or recovery)

    Expected payload from Zabbix:
    {
        "event_id": "12345",
        "event_status": "1",  // 0=OK, 1=PROBLEM
        "event_severity": "5", // 0-5 severity levels
        "host_id": "10770",
        "host_name": "IP Camera 01",
        "host_ip": "192.168.1.11",
        "trigger_description": "Camera is offline",
        "timestamp": "2026-01-01T10:00:00Z"
    }
    """
    try:
        # Get webhook payload
        webhook_payload = request.get_json()

        if not webhook_payload:
            logger.warning("Received empty webhook payload")
            return jsonify({'error': 'Empty payload'}), 400

        logger.info(f"Received Zabbix webhook: {json.dumps(webhook_payload, indent=2)}")

        # Transform webhook to incident structure
        incident_data = transform_zabbix_webhook_to_incident(webhook_payload)

        # Normalize timestamp format: Zabbix sends "2026.01.02T22:15:31Z" but SQLite needs "2026-01-02T22:15:31Z"
        if 'timestamp' in incident_data and incident_data['timestamp']:
            incident_data['timestamp'] = incident_data['timestamp'].replace('.', '-', 2)
            logger.debug(f"Normalized timestamp: {incident_data['timestamp']}")

        # Generate incident ID
        incident_id = f"INC-{datetime.utcnow().strftime('%Y%m%d%H%M%S')}-{uuid4().hex[:8]}"

        # Transform to NGSI-LD format
        ngsi_ld = transform_incident_to_ngsi_ld(incident_data, incident_id, SITE_ID)

        # Check if camera exists in database
        camera_id = incident_data['camera_id']
        camera = camera_dao.get_by_id(camera_id)

        if not camera:
            # Camera not in registry yet, check by Zabbix host_id
            zabbix_host_id = webhook_payload.get('host_id')
            if zabbix_host_id:
                camera = camera_dao.get_by_zabbix_host_id(zabbix_host_id)
                if camera:
                    camera_id = camera['camera_id']
                    incident_data['camera_id'] = camera_id

        # If camera still doesn't exist, try to find by IP address
        if not camera:
            host_ip = webhook_payload.get('host_ip')
            if host_ip and host_ip != 'unknown':
                # Try to find camera by IP address
                camera = camera_dao.get_by_ip(host_ip)
                if camera:
                    # Found existing camera with same IP, use it
                    camera_id = camera['camera_id']
                    incident_data['camera_id'] = camera_id
                    logger.info(f"Found existing camera by IP {host_ip}: {camera_id}")

                    # Update zabbix_host_id if changed
                    if camera['zabbix_host_id'] != webhook_payload.get('host_id'):
                        logger.warning(f"Zabbix host_id changed for {camera_id}: {camera['zabbix_host_id']} -> {webhook_payload.get('host_id')}")
                        # Update camera with new zabbix_host_id using batch_upsert
                        updated_camera = camera.copy()
                        updated_camera['zabbix_host_id'] = webhook_payload.get('host_id')
                        camera_dao.batch_upsert([updated_camera])
                        logger.info(f"✅ Updated zabbix_host_id for {camera_id}")

        # If camera truly doesn't exist, create it
        if not camera:
            logger.info(f"Camera {camera_id} not found, creating new camera record...")
            new_camera = {
                'camera_id': camera_id,
                'zabbix_host_id': webhook_payload.get('host_id'),
                'hostname': webhook_payload.get('host_name', f'Camera-{camera_id}'),
                'ip_address': webhook_payload.get('host_ip', 'unknown'),
                'status': 'offline',
                'site_id': SITE_ID
            }
            camera_dao.insert(new_camera)
            logger.info(f"✅ Created new camera record: {camera_id}")
            camera = new_camera

        # Check if this is a recovery event (event_status = RESOLVED or OK)
        event_status = webhook_payload.get('event_status', 'PROBLEM')
        is_recovery = event_status in ['RESOLVED', 'OK', '0']

        if is_recovery:
            # For recovery events, try to update existing incident
            zabbix_event_id = incident_data.get('zabbix_event_id')
            existing_incident = incident_dao.get_by_zabbix_event_id(zabbix_event_id)

            if existing_incident:
                # Update existing incident with resolution
                incident_dao.update_resolved(existing_incident['incident_id'], incident_data['timestamp'])
                logger.info(f"✅ Updated incident resolution: {existing_incident['incident_id']} | Camera: {camera_id}")
                incident_id = existing_incident['incident_id']
            else:
                # Edge case: recovery without prior problem event, insert it
                logger.warning(f"Recovery event for unknown incident (event_id={zabbix_event_id}), inserting new record")
                incident_record = {
                    'incident_id': incident_id,
                    'camera_id': camera_id,
                    'zabbix_event_id': zabbix_event_id,
                    'incident_type': incident_data['incident_type'],
                    'severity': incident_data['severity'],
                    'detected_at': incident_data['timestamp'],
                    'resolved_at': incident_data['timestamp'],  # Same time for edge case
                    'duration_seconds': 0,
                    'ngsi_ld': ngsi_ld
                }
                incident_dao.insert(incident_record)
                logger.info(f"✅ Stored recovery incident (no prior problem): {incident_id} | Camera: {camera_id}")
        else:
            # Problem event - insert new incident
            incident_record = {
                'incident_id': incident_id,
                'camera_id': camera_id,
                'zabbix_event_id': incident_data.get('zabbix_event_id'),
                'incident_type': incident_data['incident_type'],
                'severity': incident_data['severity'],
                'detected_at': incident_data['timestamp'],
                'ngsi_ld': ngsi_ld
            }
            incident_dao.insert(incident_record)
            logger.info(f"✅ Stored incident: {incident_id} | Type: {incident_data['incident_type']} | Camera: {camera_id}")

        # Update camera status if exists
        if camera:
            new_status = 'offline' if incident_data['incident_type'] == 'camera_offline' else 'online'
            camera_dao.update_status(camera_id, new_status)
            logger.info(f"✅ Updated camera {camera_id} status to {new_status}")

        # Return success response
        return jsonify({
            'status': 'success',
            'incident_id': incident_id,
            'camera_id': camera_id,
            'incident_type': incident_data['incident_type'],
            'severity': incident_data['severity'],
            'message': 'Incident stored successfully'
        }), 200

    except Exception as e:
        logger.error(f"Error processing Zabbix webhook: {e}", exc_info=True)
        return jsonify({
            'status': 'error',
            'error': str(e)
        }), 500


@app.route('/zabbix/events', methods=['GET'])
def list_recent_events():
    """List recent incidents (for debugging)"""
    try:
        recent = incident_dao.get_recent(hours=24, limit=50)
        return jsonify({
            'total': len(recent),
            'incidents': [
                {
                    'incident_id': inc['incident_id'],
                    'camera_id': inc['camera_id'],
                    'incident_type': inc['incident_type'],
                    'severity': inc['severity'],
                    'detected_at': inc['detected_at'],
                    'synced': inc['synced_to_cloud'] == 1
                }
                for inc in recent
            ]
        }), 200
    except Exception as e:
        logger.error(f"Error listing incidents: {e}")
        return jsonify({'error': str(e)}), 500


def main(host='0.0.0.0', port=8081):
    """Run Flask webhook server"""
    logger.info("=" * 70)
    logger.info("  Zabbix Event Subscriber - Webhook Server")
    logger.info("=" * 70)
    logger.info(f"  Site ID: {SITE_ID}")
    logger.info(f"  Listening on: http://{host}:{port}")
    logger.info(f"  Webhook endpoint: http://{host}:{port}/zabbix/events")
    logger.info(f"  Health check: http://{host}:{port}/health")
    logger.info("=" * 70)

    # Run Flask server
    app.run(host=host, port=port, debug=False)


if __name__ == '__main__':
    import argparse

    parser = argparse.ArgumentParser(description='Zabbix Event Subscriber Webhook Server')
    parser.add_argument('--host', default='0.0.0.0', help='Host to bind to')
    parser.add_argument('--port', type=int, default=8081, help='Port to listen on')

    args = parser.parse_args()

    main(host=args.host, port=args.port)
