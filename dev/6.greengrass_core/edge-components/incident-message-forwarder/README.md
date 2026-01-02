# IncidentMessageForwarder Component

**Version:** 1.0.0
**Component Name:** com.aismc.IncidentMessageForwarder
**Type:** Greengrass Generic Component

## Purpose

Forwards incidents from local SQLite message queue to AWS IoT Core via MQTT. Provides offline resilience with automatic retry logic and Device Shadow updates.

## Architecture

```
SQLite message_queue
    ↓ (Poll every 10s)
IncidentMessageForwarder
    ├─→ MQTT Publish (IoT Core)
    └─→ Device Shadow Update
```

## Features

- **Offline Resilience**: Messages queued in SQLite when network unavailable
- **Automatic Retry**: Exponential backoff with configurable max retries
- **Device Shadow Sync**: Updates shadow with latest device state
- **Batch Processing**: Process multiple messages per cycle (configurable)
- **Priority Queue**: High-severity incidents processed first
- **Failure Tracking**: Failed messages logged with error details

## Configuration

| Parameter | Default | Description |
|-----------|---------|-------------|
| `site_id` | `site-001` | Site identifier for MQTT topic routing |
| `poll_interval` | `10` | Seconds between queue polls |
| `batch_size` | `10` | Max messages to process per cycle |
| `max_retries` | `5` | Max retry attempts before marking as failed |
| `log_level` | `INFO` | Logging level |

## MQTT Topics

### Published Topics:
- `aismc/incidents/{site_id}` - Incident notifications

### Message Format (NGSI-LD):
```json
{
  "@context": "https://uri.etsi.org/ngsi-ld/v1/ngsi-ld-core-context.jsonld",
  "id": "urn:ngsi-ld:Incident:INC-20260101100000-abc12345",
  "type": "Incident",
  "device_id": {
    "type": "Property",
    "value": "CAM-192-168-1-100"
  },
  "incident_type": {
    "type": "Property",
    "value": "camera_offline"
  },
  "severity": {
    "type": "Property",
    "value": "high"
  },
  "detected_at": {
    "type": "Property",
    "value": "2026-01-01T10:00:00Z",
    "observedAt": "2026-01-01T10:00:00Z"
  }
}
```

## Device Shadow Updates

Component updates named shadow for each device:

```json
{
  "state": {
    "reported": {
      "last_incident": "INC-20260101100000-abc12345",
      "last_update": "2026-01-01T10:00:05Z",
      "status": "offline"
    }
  }
}
```

## Dependencies

- **Python Packages**: `awsiotsdk==1.11.9`
- **Greengrass**: Nucleus >= 2.0.0
- **Database**: SQLite with message_queue table
- **DAO Layer**: MessageQueueDAO, IncidentDAO

## Deployment

### Via Terraform (Recommended)

```bash
cd /home/sysadmin/2025/aismc/aws-aiops/dev/6.greengrass_core
terraform apply -target=null_resource.deploy_incident_forwarder
```

### Manual Testing (Development)

```bash
# Install dependencies
pip3 install awsiotsdk==1.11.9

# Run forwarder
python3 src/forwarder_service.py --site-id site-001 --poll-interval 10
```

## Monitoring

### Check Component Status
```bash
sudo /greengrass/v2/bin/greengrass-cli component list | grep IncidentMessageForwarder
```

### View Logs
```bash
sudo tail -f /greengrass/v2/logs/com.aismc.IncidentMessageForwarder.log
```

### Check Message Queue Status
```bash
sudo sqlite3 /var/greengrass/database/greengrass.db \
  "SELECT status, COUNT(*) FROM message_queue GROUP BY status;"
```

## Retry Logic

| Attempt | Wait Time | Action |
|---------|-----------|--------|
| 1 | 0s | Immediate |
| 2 | 10s | First retry |
| 3 | 10s | Second retry |
| 4 | 10s | Third retry |
| 5 | 10s | Fourth retry |
| 6+ | - | Mark as failed |

## Statistics

Component logs statistics every 10 iterations (100s):

```json
{
  "pending_messages": 5,
  "failed_messages": 2,
  "max_retries": 5,
  "poll_interval": 10,
  "site_id": "site-001",
  "ipc_connected": true
}
```

## Troubleshooting

### No Messages Being Processed

**Check if forwarder is running:**
```bash
sudo /greengrass/v2/bin/greengrass-cli component list | grep IncidentMessageForwarder
```

**Check if messages exist:**
```bash
sudo sqlite3 /var/greengrass/database/greengrass.db \
  "SELECT COUNT(*) FROM message_queue WHERE status='pending';"
```

### IPC Connection Failed

**Error:** `Failed to connect to Greengrass IPC`

**Solution:**
- Ensure component is running as Greengrass component (not standalone)
- Check Greengrass Nucleus is running
- Verify IPC socket exists: `/greengrass/v2/ipc.socket`

### MQTT Publish Failed

**Check AWS IoT Core connectivity:**
```bash
aws iot describe-endpoint --endpoint-type iot:Data-ATS
```

**Check Thing exists:**
```bash
aws iot describe-thing --thing-name GreengrassCore-site-001-hanoi
```

**Check policy permissions:**
- Policy must allow `iot:Publish` on topic `aismc/incidents/*`
- Policy must allow `iot:UpdateThingShadow`

### Shadow Update Failed

**Check named shadow permissions:**
```bash
aws iot-data get-thing-shadow \
  --thing-name GreengrassCore-site-001-hanoi \
  --shadow-name CAM-192-168-1-100 \
  /dev/stdout
```

## Database Schema

### message_queue Table

```sql
CREATE TABLE message_queue (
    message_id TEXT PRIMARY KEY,
    topic TEXT NOT NULL,
    payload TEXT NOT NULL,
    status TEXT DEFAULT 'pending',
    priority INTEGER DEFAULT 3,
    attempts INTEGER DEFAULT 0,
    max_attempts INTEGER DEFAULT 3,
    scheduled_at DATETIME DEFAULT CURRENT_TIMESTAMP,
    created_at DATETIME DEFAULT CURRENT_TIMESTAMP,
    last_attempt_at DATETIME,
    last_error TEXT
);
```

## Related Components

- **com.aismc.ZabbixEventSubscriber** - Receives webhooks, enqueues messages
- **com.aismc.ZabbixHostRegistrySync** - Syncs device metadata
- **Edge Database DAO Layer** - Provides SQLite data access

## License

AISMC Internal Use Only
