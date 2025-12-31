# Data Layer Module

DynamoDB tables and Timestream database for storing camera data and incidents.

## Purpose

Provide persistent storage for:
- Camera device registry (catalog)
- Real-time incident tracking
- Time-series metrics

## Resources Created

### DynamoDB Tables

**DeviceRegistry** (Camera catalog)
- Hash Key: `entity_id`
- GSIs: `site_id-index`, `device_type-index`
- Purpose: Static camera catalog (updated 1x/day)

**CameraIncidents** (Incident tracking)
- Hash Key: `incident_id`
- Range Key: `timestamp`
- GSIs:
  - `site_id-timestamp-index`
  - `entity_id-timestamp-index`
  - `incident_type-timestamp-index`
  - `status-timestamp-index`
- TTL: Enabled on `ttl` attribute
- Purpose: Real-time incident events

### Timestream Database

**iot-metrics** database with tables:
- `camera-metrics`: Individual camera performance (24h memory, 1 year magnetic)
- `site-metrics`: Site-level aggregates (24h memory, 1 year magnetic)
- `system-metrics`: System health (7d memory, 2 years magnetic)

## Usage

```bash
# Deploy
terraform init
terraform plan -out=tfplan
terraform apply tfplan

# View outputs
terraform output
terraform output device_registry_table_name

# Test DynamoDB
aws dynamodb scan \
  --table-name aismc-dev-device-registry \
  --limit 10

# Test Timestream
aws timestream-query query \
  --query-string "SELECT * FROM \"aismc-dev-iot-metrics\".\"camera-metrics\" LIMIT 10"
```

## Outputs

- `device_registry_table_name`: DeviceRegistry table name
- `camera_incidents_table_name`: CameraIncidents table name
- `timestream_database_name`: Timestream database name
- `timestream_tables`: Map of Timestream table names

## Cost

- **DynamoDB**: Pay-per-request (on-demand)
  - Setup phase: $0-4/month
  - Production: ~$3/month with 15K cameras
- **Timestream**: Pay for storage and queries
  - Setup phase: $0
  - Production: ~$2/month

## Dependencies

None - this module is independent

## Data Model

**DeviceRegistry Item**:
```json
{
  "entity_id": "urn:ngsi-ld:Camera:camera-001",
  "site_id": "site-001",
  "device_type": "IP_Camera",
  "@context": "https://uri.etsi.org/ngsi-ld/v1/ngsi-ld-core-context.jsonld",
  "type": "Camera"
}
```

**CameraIncidents Item**:
```json
{
  "incident_id": "inc-001",
  "timestamp": "2025-12-29T10:00:00Z",
  "site_id": "site-001",
  "entity_id": "camera-001",
  "incident_type": "camera_offline",
  "status": "active",
  "priority": "critical"
}
```
