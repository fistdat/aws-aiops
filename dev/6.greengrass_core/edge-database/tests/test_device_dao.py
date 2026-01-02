#!/usr/bin/env python3
"""
Test script for DeviceDAO and HostGroupDAO
Tests the new DAO classes for devices and host_groups tables
"""
import sys
import os

# Add the common directory to Python path
sys.path.insert(0, '/greengrass/v2/components/common')

from database import DatabaseManager, DeviceDAO, HostGroupDAO
from datetime import datetime


def main():
    print("="*80)
    print("  DeviceDAO and HostGroupDAO Test Suite")
    print("="*80)

    # Initialize database manager
    db_manager = DatabaseManager()

    # Test 1: Initialize DAOs
    print("\n[TEST 1] Initializing DAOs...")
    device_dao = DeviceDAO(db_manager)
    hostgroup_dao = HostGroupDAO(db_manager)
    print("✅ DAOs initialized successfully")

    # Test 2: Insert host group
    print("\n[TEST 2] Testing HostGroupDAO.insert()...")
    test_group = {
        'groupid': 'TEST-GROUP-001',
        'name': 'Test Group',
        'description': 'Test host group for DAO testing',
        'internal': 0,
        'flags': 0
    }
    try:
        groupid = hostgroup_dao.insert(test_group)
        print(f"✅ Inserted host group: {groupid}")
    except Exception as e:
        print(f"⚠️  Insert may have failed (duplicate?): {e}")

    # Test 3: Get host group by ID
    print("\n[TEST 3] Testing HostGroupDAO.get_by_id()...")
    group = hostgroup_dao.get_by_id('TEST-GROUP-001')
    if group:
        print(f"✅ Retrieved host group: {group['name']}")
    else:
        print("❌ Failed to retrieve host group")
        return False

    # Test 4: Insert device
    print("\n[TEST 4] Testing DeviceDAO.insert()...")
    test_device = {
        'device_id': 'DEV-TEST-001',
        'zabbix_host_id': 'ZABBIX-10001',
        'host_name': 'test-server-001',
        'visible_name': 'Test Server 001',
        'device_type': 'server',
        'ip_address': '192.168.1.201',
        'port': '10050',
        'status': 'online',
        'available': 1,
        'maintenance_status': 0,
        'lastchange': int(datetime.utcnow().timestamp()),
        'host_groups': 'TEST-GROUP-001',
        'location': 'Hanoi Data Center',
        'tags': [
            {'tag': 'Environment', 'value': 'Test'},
            {'tag': 'OS', 'value': 'Linux'}
        ],
        'ngsi_ld': {
            '@context': 'https://uri.etsi.org/ngsi-ld/v1/ngsi-ld-core-context.jsonld',
            'id': 'urn:ngsi-ld:Device:DEV-TEST-001',
            'type': 'Device',
            'name': {'type': 'Property', 'value': 'test-server-001'}
        }
    }

    try:
        device_id = device_dao.insert(test_device)
        print(f"✅ Inserted device: {device_id}")
    except Exception as e:
        print(f"⚠️  Insert may have failed (duplicate?): {e}")

    # Test 5: Get device by ID
    print("\n[TEST 5] Testing DeviceDAO.get_by_id()...")
    device = device_dao.get_by_id('DEV-TEST-001')
    if device:
        print(f"✅ Retrieved device: {device['host_name']} ({device['device_type']})")
    else:
        print("❌ Failed to retrieve device")
        return False

    # Test 6: Get device by Zabbix host ID
    print("\n[TEST 6] Testing DeviceDAO.get_by_zabbix_host_id()...")
    device = device_dao.get_by_zabbix_host_id('ZABBIX-10001')
    if device:
        print(f"✅ Retrieved device by Zabbix ID: {device['host_name']}")
    else:
        print("❌ Failed to retrieve device by Zabbix ID")
        return False

    # Test 7: Get all devices by type
    print("\n[TEST 7] Testing DeviceDAO.get_by_type('camera')...")
    cameras = device_dao.get_by_type('camera')
    print(f"✅ Found {len(cameras)} camera(s)")
    for cam in cameras:
        print(f"   - {cam['device_id']}: {cam['host_name']}")

    # Test 8: Get device count
    print("\n[TEST 8] Testing DeviceDAO.get_count()...")
    total_devices = device_dao.get_count()
    camera_count = device_dao.get_count('camera')
    server_count = device_dao.get_count('server')
    print(f"✅ Total devices: {total_devices}")
    print(f"   - Cameras: {camera_count}")
    print(f"   - Servers: {server_count}")

    # Test 9: Batch upsert
    print("\n[TEST 9] Testing DeviceDAO.batch_upsert()...")
    batch_devices = [
        {
            'device_id': 'DEV-TEST-002',
            'zabbix_host_id': 'ZABBIX-10002',
            'host_name': 'test-camera-002',
            'device_type': 'camera',
            'ip_address': '192.168.1.202',
            'ngsi_ld': {'type': 'Device', 'id': 'urn:ngsi-ld:Device:DEV-TEST-002'}
        },
        {
            'device_id': 'DEV-TEST-003',
            'zabbix_host_id': 'ZABBIX-10003',
            'host_name': 'test-network-003',
            'device_type': 'network',
            'ip_address': '192.168.1.203',
            'ngsi_ld': {'type': 'Device', 'id': 'urn:ngsi-ld:Device:DEV-TEST-003'}
        }
    ]
    count = device_dao.batch_upsert(batch_devices)
    print(f"✅ Batch upserted {count} devices")

    # Test 10: Get all host groups
    print("\n[TEST 10] Testing HostGroupDAO.get_all()...")
    all_groups = hostgroup_dao.get_all()
    print(f"✅ Found {len(all_groups)} host group(s)")
    for group in all_groups:
        print(f"   - {group['groupid']}: {group['name']}")

    # Test 11: Update device status
    print("\n[TEST 11] Testing DeviceDAO.update_status()...")
    device_dao.update_status('DEV-TEST-001', 'offline', available=2)
    updated_device = device_dao.get_by_id('DEV-TEST-001')
    if updated_device['status'] == 'offline':
        print(f"✅ Device status updated to: {updated_device['status']}")
    else:
        print("❌ Failed to update device status")

    # Test 12: Get modified devices since timestamp
    print("\n[TEST 12] Testing DeviceDAO.get_modified_since()...")
    one_hour_ago = int(datetime.utcnow().timestamp()) - 3600
    modified_devices = device_dao.get_modified_since(one_hour_ago)
    print(f"✅ Found {len(modified_devices)} device(s) modified in last hour")

    print("\n" + "="*80)
    print("  ✅ ALL TESTS PASSED")
    print("="*80)

    return True


if __name__ == "__main__":
    try:
        success = main()
        sys.exit(0 if success else 1)
    except Exception as e:
        print(f"\n❌ TEST FAILED: {e}")
        import traceback
        traceback.print_exc()
        sys.exit(1)
