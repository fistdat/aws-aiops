# ZabbixEventSubscriber Component

**Version:** 1.0.0
**Component Name:** com.aismc.ZabbixEventSubscriber
**Type:** Greengrass Generic Component

## Purpose

HTTP webhook server that receives Zabbix problem/recovery events in real-time. Stores incidents in the local SQLite database for offline resilience and later synchronization to AWS IoT Core.

## Architecture

```
┌──────────┐      Webhook       ┌──────────────────────┐      DAO       ┌────────────┐
│  Zabbix  │ ─────────────────> │ ZabbixEventSubscriber │ ────────────> │  SQLite DB │
│  Server  │   HTTP POST        │   Flask Server        │   Insert      │   (Local)  │
└──────────┘   Port 8081        └──────────────────────┘               └────────────┘
```

## Features

- **Real-time Event Processing**: Receives Zabbix webhook events via HTTP POST
- **Offline Resilience**: Stores incidents in local SQLite database
- **NGSI-LD Compliance**: Transforms events to ETSI NGSI-LD standard
- **Health Monitoring**: Provides `/health` endpoint for monitoring
- **Camera Status Updates**: Automatically updates camera status (online/offline)
- **Event Debugging**: `/zabbix/events` GET endpoint lists recent incidents

## Endpoints

### POST /zabbix/events
Receives Zabbix webhook events.

**Expected Payload:**
```json
{
  "event_id": "12345",
  "event_status": "1",
  "event_severity": "4",
  "host_id": "10770",
  "host_name": "IP Camera 01",
  "host_ip": "192.168.1.11",
  "trigger_description": "Camera is offline",
  "timestamp": "2026-01-01T10:00:00Z"
}
```

**Response:**
```json
{
  "status": "success",
  "incident_id": "INC-20260101100000-abc12345",
  "camera_id": "CAM-192-168-1-11",
  "incident_type": "camera_offline",
  "severity": "high",
  "message": "Incident stored successfully"
}
```

### GET /health
Health check endpoint.

**Response:**
```json
{
  "status": "healthy",
  "component": "ZabbixEventSubscriber",
  "version": "1.0.0",
  "database": {
    "status": "connected",
    "mode": "wal",
    "total_cameras": 6,
    "total_incidents": 12
  }
}
```

### GET /zabbix/events
List recent incidents (last 24 hours, max 50).

## Configuration

Component configuration parameters (set in Greengrass deployment):

| Parameter | Default | Description |
|-----------|---------|-------------|
| `webhook_host` | `0.0.0.0` | Host to bind Flask server |
| `webhook_port` | `8081` | Port to listen on |
| `site_id` | `site-001` | Site identifier |
| `log_level` | `INFO` | Logging level |

## Dependencies

- Flask 3.0.0
- Werkzeug 3.0.1
- Python 3.10+

Installed automatically during Greengrass component deployment.

## Deployment

### Via Terraform (Recommended)

```bash
cd /home/sysadmin/2025/aismc/aws-aiops/dev/6.greengrass_core
terraform apply -target=module.zabbix_event_subscriber
```

### Manual Testing (Development)

```bash
# 1. Install dependencies
pip3 install -r requirements.txt

# 2. Run server
python3 src/webhook_server.py --host 0.0.0.0 --port 8081

# 3. Test webhook (in another terminal)
chmod +x test_webhook.sh
./test_webhook.sh
```

## Zabbix Webhook Configuration

### 1. Create Media Type

**Zabbix UI → Administration → Media types → Create media type**

- **Name:** Greengrass Event Webhook
- **Type:** Webhook
- **Script:**
```javascript
try {
    var params = JSON.parse(value);
    var request = new HttpRequest();
    request.addHeader('Content-Type: application/json');

    var payload = JSON.stringify({
        event_id: params.event_id || '',
        event_status: params.event_status || '1',
        event_severity: params.event_severity || '0',
        host_id: params.host_id || '',
        host_name: params.host_name || '',
        host_ip: params.host_ip || '',
        trigger_description: params.trigger_description || '',
        timestamp: params.timestamp || new Date().toISOString()
    });

    var response = request.post(
        params.webhook_url + '/zabbix/events',
        payload
    );

    return response;
} catch (error) {
    throw 'Webhook error: ' + error;
}
```

- **Parameters:**
  - `webhook_url` = `http://{GREENGRASS_IP}:8081`
  - `event_id` = `{EVENT.ID}`
  - `event_status` = `{EVENT.STATUS}`
  - `event_severity` = `{EVENT.SEVERITY}`
  - `host_id` = `{HOST.ID}`
  - `host_name` = `{HOST.NAME}`
  - `host_ip` = `{HOST.IP}`
  - `trigger_description` = `{TRIGGER.DESCRIPTION}`
  - `timestamp` = `{DATE}T{TIME}Z`

### 2. Create Action

**Zabbix UI → Configuration → Actions → Create action**

- **Name:** Send to Greengrass
- **Conditions:**
  - Trigger severity >= Warning
  - Host group = Camera Group
- **Operations:**
  - Send to users: Admin
  - Send only to: Greengrass Event Webhook
  - Custom message: (use default)

### 3. Test

1. Stop a camera or simulate offline event
2. Check Greengrass logs: `sudo tail -f /greengrass/v2/logs/com.aismc.ZabbixEventSubscriber.log`
3. Verify incident in database:
```bash
sudo sqlite3 /var/greengrass/database/greengrass.db \
  "SELECT incident_id, camera_id, incident_type, severity FROM incidents ORDER BY created_at DESC LIMIT 5;"
```

## Troubleshooting

### Port Already in Use
```bash
# Check what's using port 8081
sudo lsof -i :8081

# Kill the process
sudo kill -9 <PID>
```

### Database Permission Error
```bash
# Fix database permissions
sudo chown sysadmin:sysadmin /var/greengrass/database/greengrass.db*
sudo chmod 664 /var/greengrass/database/greengrass.db*
sudo usermod -aG ggc_group sysadmin
```

### Flask Server Not Starting
```bash
# Check Greengrass component logs
sudo tail -f /greengrass/v2/logs/com.aismc.ZabbixEventSubscriber.log

# Check component status
sudo /greengrass/v2/bin/greengrass-cli component list
```

### Webhook Not Receiving Events
```bash
# Test webhook endpoint directly
curl -X POST http://localhost:8081/zabbix/events \
  -H "Content-Type: application/json" \
  -d '{"event_id": "TEST", "host_name": "test", "event_status": "1"}'

# Check Zabbix webhook configuration
# Zabbix UI → Administration → Media types → Test
```

## Logs

Component logs are written to:
```
/greengrass/v2/logs/com.aismc.ZabbixEventSubscriber.log
```

View logs in real-time:
```bash
sudo tail -f /greengrass/v2/logs/com.aismc.ZabbixEventSubscriber.log
```

## Database Schema

Incidents are stored in the `incidents` table:

```sql
CREATE TABLE incidents (
    incident_id TEXT PRIMARY KEY,
    camera_id TEXT,
    zabbix_event_id TEXT,
    incident_type TEXT,
    severity TEXT,
    detected_at TEXT,
    resolved_at TEXT,
    synced_to_cloud INTEGER DEFAULT 0,
    ngsi_ld TEXT,
    created_at DATETIME DEFAULT CURRENT_TIMESTAMP
);
```

## Next Steps

After deploying ZabbixEventSubscriber:

1. **Deploy IncidentMessageForwarder** - Forwards incidents to AWS IoT Core
2. **Configure Zabbix Webhook** - Set up Media Type and Actions
3. **Test End-to-End** - Trigger camera offline event and verify cloud sync

## Related Components

- **com.aismc.IncidentMessageForwarder** - Syncs incidents to AWS IoT Core
- **com.aismc.ZabbixHostRegistrySync** - Syncs host metadata from Zabbix API
- **Edge Database DAO Layer** - Provides SQLite data access

## License

AISMC Internal Use Only
