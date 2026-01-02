# Zabbix Webhook Configuration Guide

**Objective**: Configure Zabbix to send camera offline events to Greengrass via webhook

**Webhook Endpoint**: `http://localhost:8081/zabbix/events`

---

## OPTION 1: Manual Configuration via Zabbix UI

### Step 1: Login to Zabbix
```
URL: http://localhost:8080
Default Credentials:
  Username: Admin
  Password: zabbix
```

### Step 2: Create Webhook Media Type

1. Navigate to: **Administration → Media types**
2. Click: **Create media type**
3. Configuration:

```
Name: Greengrass Webhook
Type: Webhook

Script:
──────────────────────────────────────────
var req = new HttpRequest();
req.addHeader('Content-Type: application/json');

try {
    var payload = {
        "event_id": value,
        "event_status": "{EVENT.STATUS}",
        "event_severity": "{EVENT.NSEVERITY}",
        "host_id": "{HOST.ID}",
        "host_name": "{HOST.NAME}",
        "host_ip": "{HOST.IP}",
        "trigger_id": "{TRIGGER.ID}",
        "trigger_name": "{TRIGGER.NAME}",
        "trigger_description": "{TRIGGER.DESCRIPTION}",
        "timestamp": "{DATE}T{TIME}Z",
        "event_value": "{EVENT.VALUE}",
        "event_date": "{EVENT.DATE}",
        "event_time": "{EVENT.TIME}"
    };
    
    Zabbix.log(4, "Sending webhook to Greengrass: " + JSON.stringify(payload));
    
    var response = req.post(
        'http://localhost:8081/zabbix/events',
        JSON.stringify(payload)
    );
    
    Zabbix.log(4, "Greengrass response: " + response);
    
    if (req.getStatus() !== 200) {
        throw "HTTP " + req.getStatus() + ": " + response;
    }
    
    return "OK";
    
} catch (error) {
    Zabbix.log(4, "Webhook error: " + error);
    throw error;
}
──────────────────────────────────────────

Parameters:
  - Name: HTTPProxy
    Value: (leave empty)

Message templates:
  Problem:
    Subject: {EVENT.NAME}
    Message: {TRIGGER.NAME}: {TRIGGER.STATUS}
    
  Problem recovery:
    Subject: Resolved: {EVENT.NAME}
    Message: {TRIGGER.NAME}: {TRIGGER.STATUS}

Enabled: ✓ (checked)
```

4. Click **Add** to save

### Step 3: Assign Media Type to Admin User

1. Navigate to: **Administration → Users**
2. Click on: **Admin** user
3. Go to: **Media** tab
4. Click: **Add**
5. Configuration:
   ```
   Type: Greengrass Webhook
   Send to: greengrass (any value works)
   When active: 1-7,00:00-24:00 (always)
   Use if severity: (select all)
   Status: Enabled
   ```
6. Click **Add**
7. Click **Update** to save user

### Step 4: Create Camera Host (if not exists)

1. Navigate to: **Configuration → Hosts**
2. Click: **Create host**
3. Configuration:
   ```
   Host name: IP Camera 01
   Visible name: Camera 192.168.1.100
   Groups: Cameras (create if not exists)
   
   Interfaces:
     Type: Agent
     IP address: 192.168.1.100
     Port: 10050
     Default: ✓
   ```
4. Click **Add**

### Step 5: Create ICMP Ping Item

1. In the host: **IP Camera 01**
2. Go to: **Items** tab
3. Click: **Create item**
4. Configuration:
   ```
   Name: ICMP Ping
   Type: Simple check
   Key: icmpping
   Host interface: 192.168.1.100
   Type of information: Numeric (unsigned)
   Update interval: 30s
   History storage period: 7d
   Enabled: ✓
   ```
5. Click **Add**

### Step 6: Create Trigger for Offline Detection

1. In the host: **IP Camera 01**
2. Go to: **Triggers** tab
3. Click: **Create trigger**
4. Configuration:
   ```
   Name: Camera {HOST.NAME} is offline
   Severity: High
   Expression: 
     last(/IP Camera 01/icmpping)=0
   
   OK event generation: Recovery expression
   Recovery expression:
     last(/IP Camera 01/icmpping)=1
   
   Allow manual close: ✓
   Enabled: ✓
   ```
5. Click **Add**

### Step 7: Create Action to Send Webhook

1. Navigate to: **Configuration → Actions → Trigger actions**
2. Click: **Create action**
3. **Action** tab:
   ```
   Name: Send camera events to Greengrass
   
   Conditions:
     A. Trigger severity >= High
     B. Host group = Cameras
   
   Enabled: ✓
   ```

4. **Operations** tab:
   ```
   Default operation step duration: 60s
   
   Operations:
     Operation type: Send message
     Send to users: Admin
     Send only to: Greengrass Webhook
     Default message: ✓
   ```

5. **Recovery operations** tab:
   ```
   Operations:
     Operation type: Send message
     Send to users: Admin
     Send only to: Greengrass Webhook
     Default message: ✓
   ```

6. Click **Add** to save

---

## OPTION 2: Automated Configuration via Zabbix API

See script: `zabbix-webhook-setup.sh` (automated)

---

## Testing the Webhook

### Test 1: Manual Test via curl
```bash
curl -X POST http://localhost:8081/zabbix/events \
  -H "Content-Type: application/json" \
  -d '{
    "event_id": "TEST-001",
    "event_status": "1",
    "event_severity": "4",
    "host_id": "10001",
    "host_name": "IP Camera 01",
    "host_ip": "192.168.1.100",
    "trigger_name": "Camera offline",
    "trigger_description": "Camera is not responding to ICMP ping",
    "timestamp": "2026-01-02T09:00:00Z"
  }'
```

Expected response:
```json
{
  "status": "success",
  "incident_id": "INC-20260102090000-xxxxx",
  "camera_id": "...",
  "incident_type": "camera_offline"
}
```

### Test 2: Verify in Database
```bash
sudo sqlite3 /var/greengrass/database/greengrass.db \
  "SELECT incident_id, camera_id, incident_type, severity, detected_at 
   FROM incidents 
   ORDER BY detected_at DESC 
   LIMIT 5;"
```

### Test 3: Simulate Camera Offline
```bash
# Option A: Disconnect camera network cable
# Option B: Block ICMP ping
sudo iptables -A OUTPUT -p icmp -d 192.168.1.100 -j DROP

# Wait 30-60 seconds for Zabbix to detect

# Check trigger status
# Zabbix UI → Monitoring → Problems

# Restore
sudo iptables -D OUTPUT -p icmp -d 192.168.1.100 -j DROP
```

---

## Verification Checklist

- [ ] Zabbix server is running
- [ ] Greengrass webhook endpoint is healthy (http://localhost:8081/health)
- [ ] Webhook media type created in Zabbix
- [ ] Media type assigned to Admin user
- [ ] Camera host created with ICMP ping item
- [ ] Trigger created for offline detection
- [ ] Action created to send webhooks
- [ ] Manual webhook test successful
- [ ] Incident stored in SQLite database
- [ ] Camera offline simulation successful
- [ ] Webhook logs show successful delivery

---

## Troubleshooting

### Webhook Not Triggered
```bash
# Check Zabbix server logs
sudo tail -f /var/log/zabbix/zabbix_server.log | grep -i webhook

# Check Greengrass logs
sudo tail -f /greengrass/v2/logs/com.aismc.ZabbixEventSubscriber.log
```

### Database Errors
```bash
# Check database integrity
sudo sqlite3 /var/greengrass/database/greengrass.db "PRAGMA integrity_check;"

# Check table schema
sudo sqlite3 /var/greengrass/database/greengrass.db ".schema incidents"
```

### Webhook Returns Error
```bash
# Check component health
curl http://localhost:8081/health

# View recent incidents
curl http://localhost:8081/zabbix/events
```

---

**Next Steps After Configuration:**
1. Monitor webhook deliveries for 24 hours
2. Verify analytics data appears in DynamoDB (after 1 hour)
3. Configure additional camera hosts
4. Set up email/SMS alerts for critical incidents

