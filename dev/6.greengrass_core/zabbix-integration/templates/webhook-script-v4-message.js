// Zabbix 7.4.x Webhook Script for Greengrass Integration
// Version: 4.0 - Using message body approach
// Fix: Zabbix 7.4.x requires parameters to be in message body

var req = new HttpRequest();
req.addHeader('Content-Type: application/json');

try {
    // In Zabbix 7.4.x, webhook parameters must be constructed manually
    // from the message body that contains macro-expanded values

    // Parse the incoming message which should contain JSON with expanded macros
    var message = value || "";
    var payload = {};

    try {
        // Try to parse message as JSON if it exists
        if (message && message.length > 0) {
            payload = JSON.parse(message);
            Zabbix.log(4, "[Greengrass Webhook v4] Parsed message: " + JSON.stringify(payload));
        } else {
            // If no message, construct from individual fields
            Zabbix.log(4, "[Greengrass Webhook v4] No message body, using fallback");
            payload = {
                error: "No message body provided - check action configuration"
            };
        }
    } catch (e) {
        Zabbix.log(3, "[Greengrass Webhook v4] Failed to parse message: " + e);
        // Fallback: treat message as plain text
        payload = {
            raw_message: message,
            error: "Failed to parse JSON: " + e
        };
    }

    Zabbix.log(4, "[Greengrass Webhook v4] Sending payload: " + JSON.stringify(payload));

    var response = req.post('http://localhost:8081/zabbix/events', JSON.stringify(payload));
    var status = req.getStatus();

    Zabbix.log(4, "[Greengrass Webhook v4] Response status: " + status + ", body: " + response);

    // Accept both 200 (OK) and 202 (Accepted)
    if (status !== 200 && status !== 202) {
        throw "HTTP " + status + ": " + response;
    }

    return "OK";

} catch (error) {
    Zabbix.log(3, "[Greengrass Webhook v4] Error: " + error);
    throw error;
}
