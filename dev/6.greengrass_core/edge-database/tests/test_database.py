#!/usr/bin/env python3
"""
Test suite for Database DAO Layer
Tests all DAO classes and NGSI-LD transformers
"""
import sys
import os
import json
from datetime import datetime
from uuid import uuid4

# Add src directory to path
sys.path.insert(0, os.path.join(os.path.dirname(__file__), '..', 'src'))

from database.connection import DatabaseManager
from database.dao import (
    CameraDAO,
    IncidentDAO,
    MessageQueueDAO,
    SyncLogDAO,
    ConfigurationDAO
)
from utils.ngsi_ld import (
    transform_camera_to_ngsi_ld,
    transform_incident_to_ngsi_ld,
    transform_zabbix_webhook_to_incident
)


def log_test(message: str, status: str = "INFO"):
    """Log test output with color"""
    colors = {
        "INFO": "\033[0;36m",     # Cyan
        "SUCCESS": "\033[0;32m",   # Green
        "ERROR": "\033[0;31m",     # Red
        "RESET": "\033[0m"
    }
    color = colors.get(status, colors["INFO"])
    print(f"{color}[{status}]{colors['RESET']} {message}")


def test_database_connection():
    """Test database connection and health check"""
    log_test("Testing database connection...")

    try:
        db = DatabaseManager()
        health = db.health_check()

        assert health['status'] == 'healthy', f"Database unhealthy: {health}"

        log_test(f"✅ Database connection successful", "SUCCESS")
        log_test(f"   Database path: {health['database_path']}", "INFO")
        log_test(f"   Cameras: {health.get('cameras', 0)}", "INFO")
        log_test(f"   Incidents: {health.get('incidents', 0)}", "INFO")

        return db

    except Exception as e:
        log_test(f"❌ Database connection failed: {e}", "ERROR")
        raise


def test_configuration_dao(db: DatabaseManager):
    """Test ConfigurationDAO operations"""
    log_test("Testing ConfigurationDAO...")

    try:
        config_dao = ConfigurationDAO(db)

        # Test get single config
        site_id = config_dao.get('site_id')
        assert site_id is not None, "site_id not found"
        log_test(f"✅ Retrieved site_id: {site_id}", "SUCCESS")

        # Test get all configs
        all_configs = config_dao.get_all()
        assert len(all_configs) > 0, "No configurations found"
        log_test(f"✅ Retrieved {len(all_configs)} configurations", "SUCCESS")

        # Test get multiple
        keys = ['site_id', 'total_cameras', 'zabbix_api_url']
        multi_configs = config_dao.get_multiple(keys)
        assert len(multi_configs) == 3, "Failed to get multiple configs"
        log_test(f"✅ Get multiple configs successful", "SUCCESS")

        # Test set config
        config_dao.set('total_cameras', '1')
        updated_value = config_dao.get('total_cameras')
        assert updated_value == '1', "Config update failed"
        log_test(f"✅ Config update successful", "SUCCESS")

        # Reset
        config_dao.set('total_cameras', '0')

    except Exception as e:
        log_test(f"❌ ConfigurationDAO test failed: {e}", "ERROR")
        raise


def test_camera_dao(db: DatabaseManager):
    """Test CameraDAO operations"""
    log_test("Testing CameraDAO...")

    try:
        camera_dao = CameraDAO(db)

        # Create test camera
        test_camera_id = f"CAM-TEST-{uuid4().hex[:8]}"
        test_camera = {
            'camera_id': test_camera_id,
            'zabbix_host_id': f"HOST-{uuid4().hex[:6]}",
            'ip_address': '192.168.1.100',
            'hostname': 'test-camera-001',
            'location': 'Building A - Floor 1',
            'site_id': 'site-001',
            'model': 'Hikvision DS-2CD2345',
            'status': 'online',
            'ngsi_ld': transform_camera_to_ngsi_ld({
                'camera_id': test_camera_id,
                'ip_address': '192.168.1.100',
                'hostname': 'test-camera-001',
                'location': 'Building A - Floor 1',
                'model': 'Hikvision DS-2CD2345',
                'status': 'online'
            }, 'site-001')
        }

        # Test insert
        camera_id = camera_dao.insert(test_camera)
        assert camera_id == test_camera_id, "Insert returned wrong ID"
        log_test(f"✅ Camera inserted: {camera_id}", "SUCCESS")

        # Test get by ID
        retrieved = camera_dao.get_by_id(camera_id)
        assert retrieved is not None, "Camera not found"
        assert retrieved['camera_id'] == test_camera_id, "Wrong camera retrieved"
        log_test(f"✅ Camera retrieved by ID", "SUCCESS")

        # Test get by Zabbix host ID
        retrieved_by_host = camera_dao.get_by_zabbix_host_id(test_camera['zabbix_host_id'])
        assert retrieved_by_host is not None, "Camera not found by Zabbix host ID"
        log_test(f"✅ Camera retrieved by Zabbix host ID", "SUCCESS")

        # Test update status
        camera_dao.update_status(camera_id, 'offline')
        updated = camera_dao.get_by_id(camera_id)
        assert updated['status'] == 'offline', "Status update failed"
        log_test(f"✅ Camera status updated", "SUCCESS")

        # Test get count
        count = camera_dao.get_count()
        assert count > 0, "Camera count should be > 0"
        log_test(f"✅ Camera count: {count}", "SUCCESS")

        # Test batch upsert (update existing)
        test_camera['status'] = 'online'
        test_camera['model'] = 'Updated Model'
        camera_dao.batch_upsert([test_camera])

        updated = camera_dao.get_by_id(camera_id)
        assert updated['model'] == 'Updated Model', "Batch upsert failed"
        log_test(f"✅ Batch upsert successful", "SUCCESS")

        return camera_id

    except Exception as e:
        log_test(f"❌ CameraDAO test failed: {e}", "ERROR")
        raise


def test_incident_dao(db: DatabaseManager, camera_id: str):
    """Test IncidentDAO operations"""
    log_test("Testing IncidentDAO...")

    try:
        incident_dao = IncidentDAO(db)

        # Create test incident
        incident_id = f"INC-TEST-{datetime.utcnow().strftime('%Y%m%d%H%M%S')}-{uuid4().hex[:8]}"
        detected_at = datetime.utcnow().isoformat() + 'Z'

        test_incident = {
            'incident_id': incident_id,
            'camera_id': camera_id,
            'zabbix_event_id': f"ZABBIX-{uuid4().hex[:8]}",
            'incident_type': 'camera_offline',
            'severity': 'critical',
            'detected_at': detected_at,
            'ngsi_ld': transform_incident_to_ngsi_ld({
                'camera_id': camera_id,
                'incident_type': 'camera_offline',
                'severity': 'critical',
                'timestamp': detected_at
            }, incident_id, 'site-001')
        }

        # Test insert
        inserted_id = incident_dao.insert(test_incident)
        assert inserted_id == incident_id, "Insert returned wrong ID"
        log_test(f"✅ Incident inserted: {incident_id}", "SUCCESS")

        # Test get by Zabbix event
        retrieved = incident_dao.get_by_zabbix_event(test_incident['zabbix_event_id'])
        assert retrieved is not None, "Incident not found by Zabbix event ID"
        log_test(f"✅ Incident retrieved by Zabbix event ID", "SUCCESS")

        # Test get pending sync
        pending = incident_dao.get_pending_sync(limit=10)
        assert len(pending) > 0, "Should have pending incidents"
        assert any(inc['incident_id'] == incident_id for inc in pending), "Test incident not in pending"
        log_test(f"✅ Pending sync incidents: {len(pending)}", "SUCCESS")

        # Test mark synced
        incident_dao.mark_synced([incident_id])
        pending_after = incident_dao.get_pending_sync(limit=10)
        assert not any(inc['incident_id'] == incident_id for inc in pending_after), "Incident still pending after mark synced"
        log_test(f"✅ Incident marked as synced", "SUCCESS")

        # Test update resolved
        resolved_at = datetime.utcnow().isoformat() + 'Z'
        incident_dao.update_resolved(incident_id, resolved_at)
        resolved = incident_dao.get_by_zabbix_event(test_incident['zabbix_event_id'])
        assert resolved['resolved_at'] is not None, "Incident not marked as resolved"
        log_test(f"✅ Incident marked as resolved", "SUCCESS")

        return incident_id

    except Exception as e:
        log_test(f"❌ IncidentDAO test failed: {e}", "ERROR")
        raise


def test_message_queue_dao(db: DatabaseManager):
    """Test MessageQueueDAO operations"""
    log_test("Testing MessageQueueDAO...")

    try:
        queue_dao = MessageQueueDAO(db)

        # Create test message
        message_id = str(uuid4())
        test_message = {
            'message_id': message_id,
            'topic': 'cameras/site-001/incidents',
            'payload': json.dumps({'test': 'data'}),
            'priority': 1,
            'max_attempts': 3
        }

        # Test enqueue
        enqueued_id = queue_dao.enqueue(test_message)
        assert enqueued_id == message_id, "Enqueue returned wrong ID"
        log_test(f"✅ Message enqueued: {message_id}", "SUCCESS")

        # Test get pending
        pending = queue_dao.get_pending(limit=10)
        assert len(pending) > 0, "Should have pending messages"
        assert any(msg['message_id'] == message_id for msg in pending), "Test message not in pending"
        log_test(f"✅ Pending messages: {len(pending)}", "SUCCESS")

        # Test increment attempt
        queue_dao.increment_attempt(message_id, "Test error")
        updated = [msg for msg in queue_dao.get_pending() if msg['message_id'] == message_id]
        assert len(updated) > 0, "Message should still be pending after 1 attempt"
        assert updated[0]['attempts'] == 1, "Attempt count not incremented"
        log_test(f"✅ Attempt incremented", "SUCCESS")

        # Test mark sent
        queue_dao.mark_sent(message_id)
        pending_after = queue_dao.get_pending()
        assert not any(msg['message_id'] == message_id for msg in pending_after), "Message still pending after mark sent"
        log_test(f"✅ Message marked as sent", "SUCCESS")

    except Exception as e:
        log_test(f"❌ MessageQueueDAO test failed: {e}", "ERROR")
        raise


def test_sync_log_dao(db: DatabaseManager):
    """Test SyncLogDAO operations"""
    log_test("Testing SyncLogDAO...")

    try:
        sync_log_dao = SyncLogDAO(db)

        # Test log sync
        sync_log_dao.log(
            sync_type='camera_registry',
            records_synced=10,
            status='success',
            duration_ms=1234
        )
        log_test(f"✅ Sync log created", "SUCCESS")

        # Test get recent
        recent = sync_log_dao.get_recent(sync_type='camera_registry', limit=5)
        assert len(recent) > 0, "Should have recent sync logs"
        log_test(f"✅ Recent sync logs: {len(recent)}", "SUCCESS")

        # Test get last successful
        last_sync = sync_log_dao.get_last_successful_sync('camera_registry')
        assert last_sync is not None, "Should have last successful sync"
        assert last_sync['status'] == 'success', "Last sync status should be success"
        log_test(f"✅ Last successful sync retrieved", "SUCCESS")

    except Exception as e:
        log_test(f"❌ SyncLogDAO test failed: {e}", "ERROR")
        raise


def test_ngsi_ld_transformers():
    """Test NGSI-LD transformation functions"""
    log_test("Testing NGSI-LD transformers...")

    try:
        # Test camera transformation
        camera_data = {
            'camera_id': 'CAM-001',
            'ip_address': '192.168.1.100',
            'hostname': 'camera-001',
            'location': 'Building A',
            'model': 'Hikvision DS-2CD2345',
            'firmware_version': '5.6.3',
            'status': 'online'
        }

        ngsi_ld_camera = transform_camera_to_ngsi_ld(camera_data, 'site-001')

        assert ngsi_ld_camera['id'] == 'urn:ngsi-ld:Camera:CAM-001', "Wrong camera URN"
        assert ngsi_ld_camera['type'] == 'Camera', "Wrong type"
        assert ngsi_ld_camera['ipAddress']['value'] == '192.168.1.100', "Wrong IP"
        log_test(f"✅ Camera NGSI-LD transformation successful", "SUCCESS")

        # Test incident transformation
        incident_data = {
            'camera_id': 'CAM-001',
            'incident_type': 'camera_offline',
            'severity': 'critical',
            'timestamp': datetime.utcnow().isoformat() + 'Z',
            'event_id': 'ZABBIX-12345'
        }

        ngsi_ld_incident = transform_incident_to_ngsi_ld(incident_data, 'INC-001', 'site-001')

        assert ngsi_ld_incident['id'] == 'urn:ngsi-ld:CameraIncident:INC-001', "Wrong incident URN"
        assert ngsi_ld_incident['type'] == 'CameraIncident', "Wrong type"
        assert ngsi_ld_incident['incidentType']['value'] == 'camera_offline', "Wrong incident type"
        log_test(f"✅ Incident NGSI-LD transformation successful", "SUCCESS")

        # Test Zabbix webhook transformation
        webhook_payload = {
            'event_id': '12345',
            'event_status': 1,  # PROBLEM
            'event_severity': '5',  # Disaster
            'host_id': '10001',
            'host_name': 'Camera-001',
            'host_ip': '192.168.1.100',
            'trigger_description': 'Camera is offline'
        }

        incident = transform_zabbix_webhook_to_incident(webhook_payload)

        assert incident['incident_type'] == 'camera_offline', "Wrong incident type from webhook"
        assert incident['severity'] == 'critical', "Wrong severity mapping"
        assert incident['camera_id'] == 'CAM-10001', "Wrong camera ID"
        log_test(f"✅ Zabbix webhook transformation successful", "SUCCESS")

    except Exception as e:
        log_test(f"❌ NGSI-LD transformer test failed: {e}", "ERROR")
        raise


def main():
    """Run all tests"""
    print("\n" + "=" * 70)
    print("  DATABASE DAO LAYER TEST SUITE")
    print("=" * 70 + "\n")

    try:
        # Test 1: Database Connection
        db = test_database_connection()
        print()

        # Test 2: Configuration DAO
        test_configuration_dao(db)
        print()

        # Test 3: Camera DAO
        camera_id = test_camera_dao(db)
        print()

        # Test 4: Incident DAO
        test_incident_dao(db, camera_id)
        print()

        # Test 5: Message Queue DAO
        test_message_queue_dao(db)
        print()

        # Test 6: Sync Log DAO
        test_sync_log_dao(db)
        print()

        # Test 7: NGSI-LD Transformers
        test_ngsi_ld_transformers()
        print()

        print("=" * 70)
        log_test("✅ ALL TESTS PASSED", "SUCCESS")
        print("=" * 70 + "\n")

        return 0

    except Exception as e:
        print("\n" + "=" * 70)
        log_test(f"❌ TEST SUITE FAILED: {e}", "ERROR")
        print("=" * 70 + "\n")
        return 1


if __name__ == "__main__":
    exit_code = main()
    sys.exit(exit_code)
