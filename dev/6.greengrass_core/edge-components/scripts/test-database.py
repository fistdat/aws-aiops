#!/usr/bin/env python3
"""
Database and DAO Layer Test Script
Tests database connectivity, schema, and DAO operations
"""

import sys
import os
from datetime import datetime
import json

# Add DAO path
DAO_PATH = '/greengrass/v2/packages/artifacts-unarchived/greengrass_database'
sys.path.insert(0, DAO_PATH)

try:
    import connection
    import dao
    DatabaseManager = connection.DatabaseManager
    CameraDAO = dao.CameraDAO
    IncidentDAO = dao.IncidentDAO
    MessageQueueDAO = dao.MessageQueueDAO
    SyncLogDAO = dao.SyncLogDAO
    ConfigurationDAO = dao.ConfigurationDAO
except ImportError as e:
    print(f"❌ Failed to import DAO modules: {e}")
    print(f"Make sure Python DAO layer is installed at: {DAO_PATH}")
    print(f"Current sys.path: {sys.path}")
    sys.exit(1)

def print_section(title):
    print(f"\n{'='*60}")
    print(f"  {title}")
    print(f"{'='*60}")

def test_database_connection():
    """Test 1: Database Connection"""
    print_section("TEST 1: Database Connection")
    try:
        db = DatabaseManager()
        print("✅ DatabaseManager initialized")

        health = db.health_check()
        print(f"✅ Health check: {health['status']}")
        print(f"   - Schema version: {health['schema_version']}")
        print(f"   - Tables: {health['table_count']}")
        print(f"   - Cameras: {health.get('cameras', 0)}")
        print(f"   - Incidents: {health.get('incidents', 0)}")

        return db
    except Exception as e:
        print(f"❌ Database connection failed: {e}")
        return None

def test_configuration_dao(db):
    """Test 2: Configuration DAO"""
    print_section("TEST 2: Configuration DAO")
    try:
        config_dao = ConfigurationDAO(db)

        # Get site_id
        site_id = config_dao.get('site_id')
        print(f"✅ site_id: {site_id}")

        # Get Zabbix API URL
        zabbix_url = config_dao.get('zabbix_api_url')
        print(f"✅ zabbix_api_url: {zabbix_url}")

        # Test set
        config_dao.set('test_key', 'test_value')
        test_value = config_dao.get('test_key')
        assert test_value == 'test_value'
        print(f"✅ Set/Get test passed")

        # Get all configs
        all_configs = config_dao.get_all()
        print(f"✅ Total configuration keys: {len(all_configs)}")

        return config_dao
    except Exception as e:
        print(f"❌ Configuration DAO test failed: {e}")
        return None

def test_camera_dao(db):
    """Test 3: Camera DAO"""
    print_section("TEST 3: Camera DAO")
    try:
        camera_dao = CameraDAO(db)

        # Test camera data
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
                'ipAddress': {'type': 'Property', 'value': '192.168.1.100'},
                'status': {'type': 'Property', 'value': 'online'}
            }
        }

        # Insert camera
        camera_id = camera_dao.insert(test_camera)
        print(f"✅ Camera inserted: {camera_id}")

        # Get camera by ID
        retrieved = camera_dao.get_by_id(camera_id)
        assert retrieved['camera_id'] == camera_id
        print(f"✅ Camera retrieved by ID")

        # Get camera by Zabbix host ID
        by_zabbix = camera_dao.get_by_zabbix_host_id('10001')
        assert by_zabbix['camera_id'] == camera_id
        print(f"✅ Camera retrieved by Zabbix host ID")

        # Update status
        camera_dao.update_status(camera_id, 'offline')
        updated = camera_dao.get_by_id(camera_id)
        assert updated['status'] == 'offline'
        print(f"✅ Camera status updated to offline")

        # Get offline cameras
        offline_cameras = camera_dao.get_offline_cameras()
        print(f"✅ Offline cameras: {len(offline_cameras)}")

        # Get count
        total_count = camera_dao.get_count()
        print(f"✅ Total cameras: {total_count}")

        return camera_dao
    except Exception as e:
        print(f"❌ Camera DAO test failed: {e}")
        import traceback
        traceback.print_exc()
        return None

def test_incident_dao(db):
    """Test 4: Incident DAO"""
    print_section("TEST 4: Incident DAO")
    try:
        incident_dao = IncidentDAO(db)

        # Test incident data
        test_incident = {
            'incident_id': 'INC-TEST-001',
            'camera_id': 'CAM-TEST-001',
            'zabbix_event_id': '12345',
            'incident_type': 'camera_offline',
            'severity': 'critical',
            'detected_at': datetime.utcnow().isoformat(),
            'ngsi_ld': {
                '@context': 'https://uri.etsi.org/ngsi-ld/v1/ngsi-ld-core-context.jsonld',
                'id': 'urn:ngsi-ld:Incident:INC-TEST-001',
                'type': 'CameraOfflineIncident',
                'severity': {'type': 'Property', 'value': 'critical'}
            }
        }

        # Insert incident
        incident_id = incident_dao.insert(test_incident)
        print(f"✅ Incident inserted: {incident_id}")

        # Get incident
        retrieved = incident_dao.get_by_id(incident_id)
        assert retrieved['incident_id'] == incident_id
        print(f"✅ Incident retrieved")

        # Get pending sync
        pending = incident_dao.get_pending_sync()
        print(f"✅ Pending incidents: {len(pending)}")

        # Mark synced
        if pending:
            incident_dao.mark_synced([pending[0]['incident_id']])
            print(f"✅ Incident marked as synced")

        # Resolve incident
        incident_dao.update_resolved(incident_id)
        resolved = incident_dao.get_by_id(incident_id)
        assert resolved['resolved_at'] is not None
        print(f"✅ Incident marked as resolved")

        return incident_dao
    except Exception as e:
        print(f"❌ Incident DAO test failed: {e}")
        import traceback
        traceback.print_exc()
        return None

def test_message_queue_dao(db):
    """Test 5: Message Queue DAO"""
    print_section("TEST 5: Message Queue DAO")
    try:
        queue_dao = MessageQueueDAO(db)

        # Enqueue message
        test_message = {
            'message_id': 'MSG-TEST-001',
            'topic': 'cameras/site-001/incidents',
            'payload': json.dumps({'test': 'data'}),
            'priority': 1
        }

        msg_id = queue_dao.enqueue(test_message)
        print(f"✅ Message enqueued: {msg_id}")

        # Get pending
        pending = queue_dao.get_pending()
        print(f"✅ Pending messages: {len(pending)}")

        # Mark sent
        if pending:
            queue_dao.mark_sent(pending[0]['message_id'])
            print(f"✅ Message marked as sent")

        return queue_dao
    except Exception as e:
        print(f"❌ Message Queue DAO test failed: {e}")
        import traceback
        traceback.print_exc()
        return None

def test_sync_log_dao(db):
    """Test 6: Sync Log DAO"""
    print_section("TEST 6: Sync Log DAO")
    try:
        sync_dao = SyncLogDAO(db)

        # Log sync
        sync_dao.log('camera_registry', 10, 'success', duration_ms=1500)
        print(f"✅ Sync operation logged")

        # Get recent logs
        recent = sync_dao.get_recent(limit=5)
        print(f"✅ Recent sync logs: {len(recent)}")

        # Get last successful
        last_sync = sync_dao.get_last_successful_sync('camera_registry')
        if last_sync:
            print(f"✅ Last successful sync: {last_sync['sync_timestamp']}")

        return sync_dao
    except Exception as e:
        print(f"❌ Sync Log DAO test failed: {e}")
        import traceback
        traceback.print_exc()
        return None

def main():
    """Run all tests"""
    print("\n" + "="*60)
    print("  Greengrass Edge Database & DAO Test Suite")
    print("="*60)

    # Run tests
    db = test_database_connection()
    if not db:
        sys.exit(1)

    config_dao = test_configuration_dao(db)
    camera_dao = test_camera_dao(db)
    incident_dao = test_incident_dao(db)
    queue_dao = test_message_queue_dao(db)
    sync_dao = test_sync_log_dao(db)

    # Summary
    print_section("TEST SUMMARY")
    tests_passed = sum([
        db is not None,
        config_dao is not None,
        camera_dao is not None,
        incident_dao is not None,
        queue_dao is not None,
        sync_dao is not None
    ])
    total_tests = 6

    print(f"\nTests Passed: {tests_passed}/{total_tests}")

    if tests_passed == total_tests:
        print("✅ All tests PASSED!")
        sys.exit(0)
    else:
        print(f"❌ {total_tests - tests_passed} test(s) FAILED")
        sys.exit(1)

if __name__ == "__main__":
    main()
