// Zabbix 7.4.x Webhook Script - Debug Version
// Purpose: Test how parameters are accessible

var req = new HttpRequest();
req.addHeader('Content-Type: application/json');

try {
    // Log what's available in the execution context
    Zabbix.log(4, "[Debug] typeof params: " + typeof params);
    Zabbix.log(4, "[Debug] typeof value: " + typeof value);

    // Try to access parameters different ways
    var payload = {};

    // Method 1: Try accessing via 'value' (Zabbix 7.x style)
    try {
        if (typeof value !== 'undefined') {
            Zabbix.log(4, "[Debug] value exists: " + JSON.stringify(value));
            payload = value;
        }
    } catch (e) {
        Zabbix.log(4, "[Debug] value access failed: " + e);
    }

    // Method 2: Try accessing via direct variable names
    try {
        payload = {
            event_id: (typeof event_id !== 'undefined') ? event_id : "UNDEFINED",
            event_status: (typeof event_status !== 'undefined') ? event_status : "UNDEFINED",
            host_name: (typeof host_name !== 'undefined') ? host_name : "UNDEFINED"
        };
        Zabbix.log(4, "[Debug] Direct access payload: " + JSON.stringify(payload));
    } catch (e) {
        Zabbix.log(4, "[Debug] Direct access failed: " + e);
    }

    // Method 3: Try accessing via params object
    try {
        if (typeof params !== 'undefined') {
            payload = {
                event_id: params.event_id || "PARAMS_UNDEFINED",
                event_status: params.event_status || "PARAMS_UNDEFINED",
                host_name: params.host_name || "PARAMS_UNDEFINED"
            };
            Zabbix.log(4, "[Debug] Params access payload: " + JSON.stringify(payload));
        }
    } catch (e) {
        Zabbix.log(4, "[Debug] Params access failed: " + e);
    }

    // Send whatever we have to webhook for testing
    var response = req.post('http://localhost:8081/zabbix/events', JSON.stringify(payload));
    var status = req.getStatus();

    Zabbix.log(4, "[Debug] Response status: " + status);
    Zabbix.log(4, "[Debug] Response body: " + response);

    return "OK - Debug test completed";

} catch (error) {
    Zabbix.log(3, "[Debug] Fatal error: " + error);
    throw error;
}
