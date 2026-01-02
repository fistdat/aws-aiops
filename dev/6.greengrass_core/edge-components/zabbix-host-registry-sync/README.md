# ZabbixHostRegistrySync Component

**Version:** 1.0.0
**Component Name:** com.aismc.ZabbixHostRegistrySync
**Type:** Greengrass Generic Component (Scheduled)

## Purpose

Scheduled sync of ALL Zabbix hosts and host groups to local SQLite database. Provides complete device inventory with incremental sync support.

## Architecture

```
Zabbix API
    ↓ (Scheduled - Daily 2AM)
ZabbixHostRegistrySync
    ├─→ hostgroup.get → host_groups table
    └─→ host.get → devices table
         ↓
    Incremental Sync (only changed hosts)
```

## Features

- **Complete Inventory**: Syncs ALL devices (cameras, servers, network devices)
- **Incremental Sync**: Only fetches hosts changed since last sync
- **Scheduled Execution**: Configurable cron schedule (default: daily 2AM)
- **Device Classification**: Auto-classifies by host groups
- **NGSI-LD Compliant**: Standard data format
- **Sync Statistics**: Tracks sync history and performance

## Configuration

| Parameter | Default | Description |
|-----------|---------|-------------|
| `zabbix_api_url` | `http://localhost:8080/api_jsonrpc.php` | Zabbix API endpoint |
| `zabbix_username` | `Admin` | Zabbix username |
| `zabbix_password` | `zabbix` | Zabbix password |
| `sync_schedule` | `0 2 * * *` | Cron schedule (2 AM daily) |
| `sync_enabled` | `true` | Enable/disable sync |
| `incremental_sync` | `true` | Enable incremental mode |
| `log_level` | `INFO` | Logging level |

## Sync Strategy

### Incremental Sync (Default)
```python
# Only fetch changed hosts
last_sync_unix = config.get('last_sync_unix')  # e.g., 1735689600
changed_hosts = zabbix.host.get({
    'filter': {'lastchange': f'{last_sync_unix}:'}
})
# Efficient - only process delta
```

### Full Sync (Force)
```python
# Fetch all hosts
all_hosts = zabbix.host.get({})  # No filter
```

## Database Tables

### devices Table
Stores ALL Zabbix hosts (cameras, servers, network devices):

```sql
INSERT INTO devices (
    device_id, zabbix_host_id, host_name, device_type,
    ip_address, status, host_groups, tags, ngsi_ld_json
) VALUES (...)
ON CONFLICT(device_id) DO UPDATE SET ...
```

### host_groups Table
Stores Zabbix host groups:

```sql
INSERT INTO host_groups (
    groupid, name, description, internal, flags
) VALUES (...)
```

## Device Classification

Component auto-classifies devices by host group names:

| Host Group Contains | Device Type |
|---------------------|-------------|
| "camera" | `camera` |
| "server" | `server` |
| "network", "switch", "router" | `network` |
| (other) | `unknown` |

## Zabbix API Integration

### Authentication (Zabbix 7.4+)
```python
# 1. Login to get Bearer token
response = zabbix.user.login({
    'username': 'Admin',
    'password': 'zabbix'
})
token = response['result']

# 2. Use token for subsequent requests
headers = {'Authorization': f'Bearer {token}'}
```

### Host Groups Sync
```python
host_groups = zabbix.hostgroup.get({
    'output': ['groupid', 'name', 'flags', 'internal']
})
```

### Hosts Sync
```python
hosts = zabbix.host.get({
    'output': ['hostid', 'host', 'name', 'status', 'available'],
    'selectGroups': ['groupid', 'name'],
    'selectInterfaces': ['ip', 'port'],
    'selectTags': ['tag', 'value'],
    'filter': {'lastchange': '1735689600:'}  # Incremental
})
```

## Deployment

### Via Terraform (Recommended)

```bash
cd /home/sysadmin/2025/aismc/aws-aiops/dev/6.greengrass_core
terraform apply -target=null_resource.deploy_registry_sync
```

### Manual Testing (Development)

```bash
# Install dependencies
pip3 install requests==2.31.0

# Run sync
python3 src/sync_service.py \
  --api-url http://localhost:8080/api_jsonrpc.php \
  --username Admin \
  --password zabbix \
  --incremental

# Force full sync
python3 src/sync_service.py \
  --api-url http://localhost:8080/api_jsonrpc.php \
  --username Admin \
  --password zabbix \
  --full
```

## Monitoring

### Check Component Status
```bash
sudo /greengrass/v2/bin/greengrass-cli component list | grep ZabbixHostRegistrySync
```

### View Logs
```bash
sudo tail -f /greengrass/v2/logs/com.aismc.ZabbixHostRegistrySync.log
```

### Check Sync History
```bash
sudo sqlite3 /var/greengrass/database/greengrass.db \
  "SELECT * FROM sync_log WHERE sync_type='host_registry' ORDER BY created_at DESC LIMIT 5;"
```

### Check Synced Devices
```bash
sudo sqlite3 /var/greengrass/database/greengrass.db \
  "SELECT device_type, COUNT(*) FROM devices GROUP BY device_type;"
```

## Scheduling

**Note:** This component runs once per deployment trigger. For true scheduled execution, use one of:

### Option A: External Cron (Recommended for Development)
```bash
# Add to crontab
0 2 * * * /usr/bin/python3 /path/to/sync_service.py --api-url ... 2>&1 | logger -t zabbix-sync
```

### Option B: Greengrass Deployment Updates
```bash
# Trigger deployment at 2 AM daily via CloudWatch Events → Lambda → CreateDeployment API
```

### Option C: Component Modification
Modify recipe to run continuous loop with sleep:
```python
while True:
    run_sync()
    sleep(86400)  # 24 hours
```

## Sync Statistics

Component tracks sync performance:

```json
{
  "sync_type": "host_registry",
  "records_synced": 127,
  "status": "success",
  "duration_ms": 3456,
  "created_at": "2026-01-01T02:00:05Z"
}
```

## Configuration Updates

Update sync schedule via Greengrass deployment:

```json
{
  "components": {
    "com.aismc.ZabbixHostRegistrySync": {
      "version": "1.0.0",
      "configurationUpdate": {
        "merge": {
          "sync_schedule": "0 */6 * * *",  // Every 6 hours
          "incremental_sync": "true"
        }
      }
    }
  }
}
```

## Troubleshooting

### Authentication Failed

**Error:** `Authentication failed - aborting sync`

**Solution:**
- Verify Zabbix credentials in configuration
- Check Zabbix API URL is accessible
- Ensure Zabbix 7.4+ (uses Bearer token auth)

### No Hosts Synced

**Check Zabbix has hosts:**
```bash
curl -X POST http://localhost:8080/api_jsonrpc.php \
  -H "Content-Type: application/json" \
  -d '{
    "jsonrpc": "2.0",
    "method": "user.login",
    "params": {"username": "Admin", "password": "zabbix"},
    "id": 1
  }'
```

### Incremental Sync Not Working

**Check last_sync_unix:**
```bash
sudo sqlite3 /var/greengrass/database/greengrass.db \
  "SELECT key, value FROM configuration WHERE key='last_sync_unix';"
```

**Force full sync:**
```bash
# Update recipe or run manually with --full flag
```

## Related Components

- **com.aismc.ZabbixEventSubscriber** - Real-time event ingestion
- **com.aismc.IncidentMessageForwarder** - Forwards incidents to cloud
- **Edge Database DAO Layer** - Provides DeviceDAO, HostGroupDAO

## License

AISMC Internal Use Only
