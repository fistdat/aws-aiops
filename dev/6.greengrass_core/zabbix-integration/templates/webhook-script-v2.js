// Zabbix 7.x Webhook Script for Greengrass Integration
// Version: 2.0
// Fix: Use direct parameter access instead of params object

var req = new HttpRequest();
req.addHeader('Content-Type: application/json');

try {
    // In Zabbix 7.x, parameters are accessed directly by name (not params.name)
    // Each parameter defined in media type becomes a variable
    var payload = {
        event_id: event_id,
        event_status: event_status,
        event_severity: event_severity,
        host_id: host_id,
        host_name: host_name,
        host_ip: host_ip,
        trigger_id: trigger_id,
        trigger_name: trigger_name,
        trigger_description: trigger_description,
        timestamp: timestamp
    };

    Zabbix.log(4, "[Greengrass Webhook v2] Payload: " + JSON.stringify(payload));

    var response = req.post('http://localhost:8081/zabbix/events', JSON.stringify(payload));
    var status = req.getStatus();

    Zabbix.log(4, "[Greengrass Webhook v2] Response status: " + status + ", body: " + response);

    // Accept both 200 (OK) and 202 (Accepted)
    if (status !== 200 && status !== 202) {
        throw "HTTP " + status + ": " + response;
    }

    return "OK";

} catch (error) {
    Zabbix.log(3, "[Greengrass Webhook v2] Error: " + error);
    throw error;
}
