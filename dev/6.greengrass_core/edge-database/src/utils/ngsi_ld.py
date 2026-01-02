"""
NGSI-LD Transformer Utilities
Transforms device and incident data to NGSI-LD format (ETSI standard)
Reference: https://www.etsi.org/deliver/etsi_gs/CIM/001_099/009/01.07.01_60/gs_CIM009v010701p.pdf
"""
from typing import Dict, Any, Optional
from datetime import datetime


# NGSI-LD context URL
NGSI_LD_CONTEXT = "https://uri.etsi.org/ngsi-ld/v1/ngsi-ld-core-context.jsonld"


def create_ngsi_ld_property(value: Any, observed_at: str = None, unit_code: str = None) -> Dict:
    """
    Create NGSI-LD Property object

    Args:
        value: Property value
        observed_at: ISO8601 timestamp when observed
        unit_code: Unit code (e.g., 'CEL' for Celsius)

    Returns:
        NGSI-LD Property dictionary
    """
    prop = {
        "type": "Property",
        "value": value
    }

    if observed_at:
        prop["observedAt"] = observed_at

    if unit_code:
        prop["unitCode"] = unit_code

    return prop


def create_ngsi_ld_relationship(object_id: str) -> Dict:
    """
    Create NGSI-LD Relationship object

    Args:
        object_id: URN of related entity

    Returns:
        NGSI-LD Relationship dictionary
    """
    return {
        "type": "Relationship",
        "object": object_id
    }


def transform_camera_to_ngsi_ld(camera_data: Dict, site_id: str) -> Dict:
    """
    Transform camera data to NGSI-LD format

    Args:
        camera_data: Raw camera data from Zabbix
        site_id: Site identifier

    Returns:
        NGSI-LD formatted camera entity
    """
    camera_id = camera_data.get('camera_id') or camera_data.get('device_id')
    timestamp = datetime.utcnow().isoformat() + "Z"

    ngsi_ld_entity = {
        "@context": NGSI_LD_CONTEXT,
        "id": f"urn:ngsi-ld:Camera:{camera_id}",
        "type": "Camera",
        "ipAddress": create_ngsi_ld_property(
            camera_data['ip_address'],
            observed_at=timestamp
        ),
        "status": create_ngsi_ld_property(
            camera_data.get('status', 'unknown'),
            observed_at=timestamp
        ),
        "location": {
            "type": "GeoProperty",
            "value": {
                "type": "Point",
                "coordinates": [0.0, 0.0]  # Default, should be updated with actual coordinates
            }
        }
    }

    # Optional properties
    if camera_data.get('hostname'):
        ngsi_ld_entity['hostname'] = create_ngsi_ld_property(
            camera_data['hostname'],
            observed_at=timestamp
        )

    if camera_data.get('location'):
        ngsi_ld_entity['physicalLocation'] = create_ngsi_ld_property(
            camera_data['location'],
            observed_at=timestamp
        )

    if camera_data.get('model'):
        ngsi_ld_entity['model'] = create_ngsi_ld_property(
            camera_data['model'],
            observed_at=timestamp
        )

    if camera_data.get('firmware_version'):
        ngsi_ld_entity['firmwareVersion'] = create_ngsi_ld_property(
            camera_data['firmware_version'],
            observed_at=timestamp
        )

    # Relationships
    ngsi_ld_entity['belongsToSite'] = create_ngsi_ld_relationship(
        f"urn:ngsi-ld:Site:{site_id}"
    )

    # Metadata
    ngsi_ld_entity['dateCreated'] = create_ngsi_ld_property(
        timestamp
    )

    ngsi_ld_entity['dateModified'] = create_ngsi_ld_property(
        timestamp
    )

    return ngsi_ld_entity


def transform_incident_to_ngsi_ld(incident_data: Dict, incident_id: str, site_id: str) -> Dict:
    """
    Transform incident data to NGSI-LD format

    Args:
        incident_data: Raw incident data from Zabbix webhook
        incident_id: Unique incident identifier
        site_id: Site identifier

    Returns:
        NGSI-LD formatted incident entity
    """
    timestamp = incident_data.get('timestamp') or datetime.utcnow().isoformat() + "Z"

    # Normalize timestamp to ISO8601 with Z
    if not timestamp.endswith('Z'):
        timestamp = timestamp.rstrip('Z') + 'Z'

    incident_type = incident_data.get('incident_type', 'camera_offline')
    camera_id = incident_data.get('camera_id')

    ngsi_ld_entity = {
        "@context": NGSI_LD_CONTEXT,
        "id": f"urn:ngsi-ld:CameraIncident:{incident_id}",
        "type": "CameraIncident",
        "incidentType": create_ngsi_ld_property(
            incident_type,
            observed_at=timestamp
        ),
        "severity": create_ngsi_ld_property(
            incident_data.get('severity', 'medium'),
            observed_at=timestamp
        ),
        "detectedAt": create_ngsi_ld_property(
            timestamp
        ),
        "status": create_ngsi_ld_property(
            "active" if incident_type == "camera_offline" else "resolved",
            observed_at=timestamp
        )
    }

    # Optional properties
    if incident_data.get('event_id') or incident_data.get('zabbix_event_id'):
        ngsi_ld_entity['externalEventId'] = create_ngsi_ld_property(
            incident_data.get('event_id') or incident_data.get('zabbix_event_id')
        )

    if incident_data.get('trigger_description'):
        ngsi_ld_entity['description'] = create_ngsi_ld_property(
            incident_data['trigger_description']
        )

    if incident_data.get('host_ip'):
        ngsi_ld_entity['deviceIpAddress'] = create_ngsi_ld_property(
            incident_data['host_ip']
        )

    # Relationships
    if camera_id:
        ngsi_ld_entity['affectedDevice'] = create_ngsi_ld_relationship(
            f"urn:ngsi-ld:Camera:{camera_id}"
        )

    ngsi_ld_entity['reportedBySite'] = create_ngsi_ld_relationship(
        f"urn:ngsi-ld:Site:{site_id}"
    )

    # Metadata
    ngsi_ld_entity['dateCreated'] = create_ngsi_ld_property(
        timestamp
    )

    return ngsi_ld_entity


def transform_zabbix_webhook_to_incident(webhook_payload: Dict) -> Dict:
    """
    Transform Zabbix webhook payload to incident data structure

    Args:
        webhook_payload: Raw payload from Zabbix webhook

    Returns:
        Normalized incident data dictionary
    """
    # Determine incident type based on event status
    # event_status: 0 = OK (camera_online), 1 = PROBLEM (camera_offline)
    event_status = webhook_payload.get('event_status') or webhook_payload.get('trigger_status')

    if event_status == '0' or event_status == 0:
        incident_type = 'camera_online'
    else:
        incident_type = 'camera_offline'

    # Map severity
    severity_map = {
        '0': 'info',      # Not classified
        '1': 'info',      # Information
        '2': 'low',       # Warning
        '3': 'medium',    # Average
        '4': 'high',      # High
        '5': 'critical'   # Disaster
    }

    event_severity = webhook_payload.get('event_severity', '3')
    severity = severity_map.get(str(event_severity), 'medium')

    return {
        'camera_id': f"CAM-{webhook_payload.get('host_id', 'UNKNOWN')}",
        'zabbix_event_id': webhook_payload.get('event_id'),
        'incident_type': incident_type,
        'severity': severity,
        'timestamp': webhook_payload.get('timestamp', datetime.utcnow().isoformat() + 'Z'),
        'event_id': webhook_payload.get('event_id'),
        'host_id': webhook_payload.get('host_id'),
        'host_name': webhook_payload.get('host_name'),
        'host_ip': webhook_payload.get('host_ip'),
        'trigger_description': webhook_payload.get('trigger_description'),
        'event_name': webhook_payload.get('event_name')
    }
