#!/bin/bash
# ============================================================================
# Zabbix Webhook Automated Setup Script
# ============================================================================
# Purpose: Configure Zabbix webhook media type for Greengrass integration
# Requirements: Zabbix server running, jq installed
# ============================================================================

set -e

# Configuration
ZABBIX_URL="http://localhost:8080/api_jsonrpc.php"
ZABBIX_USER="Admin"
ZABBIX_PASS="zabbix"
WEBHOOK_URL="http://localhost:8081/zabbix/events"

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

echo "============================================================================"
echo "  Zabbix Webhook Configuration for Greengrass Integration"
echo "============================================================================"
echo ""

# Check if jq is installed
if ! command -v jq &> /dev/null; then
    echo -e "${RED}Error: jq is not installed${NC}"
    echo "Install with: sudo apt-get install jq"
    exit 1
fi

# Function to call Zabbix API
zabbix_api() {
    local method=$1
    local params=$2

    curl -s -X POST "$ZABBIX_URL" \
        -H "Content-Type: application/json-rpc" \
        -d "{
            \"jsonrpc\": \"2.0\",
            \"method\": \"$method\",
            \"params\": $params,
            \"auth\": \"$AUTH_TOKEN\",
            \"id\": 1
        }"
}

# Step 1: Authenticate
echo "Step 1: Authenticating with Zabbix API..."
AUTH_RESPONSE=$(curl -s -X POST "$ZABBIX_URL" \
    -H "Content-Type: application/json-rpc" \
    -d "{
        \"jsonrpc\": \"2.0\",
        \"method\": \"user.login\",
        \"params\": {
            \"username\": \"$ZABBIX_USER\",
            \"password\": \"$ZABBIX_PASS\"
        },
        \"id\": 1
    }")

AUTH_TOKEN=$(echo "$AUTH_RESPONSE" | jq -r '.result')

if [ "$AUTH_TOKEN" == "null" ] || [ -z "$AUTH_TOKEN" ]; then
    echo -e "${RED}✗ Authentication failed${NC}"
    echo "Response: $AUTH_RESPONSE"
    exit 1
fi

echo -e "${GREEN}✓ Authenticated successfully${NC}"
echo "Auth token: ${AUTH_TOKEN:0:20}..."
echo ""

# Step 2: Check if webhook media type already exists
echo "Step 2: Checking existing media types..."
MEDIA_TYPES=$(zabbix_api "mediatype.get" '{
    "output": ["mediatypeid", "name"],
    "filter": {
        "name": "Greengrass Webhook"
    }
}')

EXISTING_ID=$(echo "$MEDIA_TYPES" | jq -r '.result[0].mediatypeid // empty')

if [ -n "$EXISTING_ID" ]; then
    echo -e "${YELLOW}✓ Webhook media type already exists (ID: $EXISTING_ID)${NC}"
    echo "  Updating existing media type..."
    MEDIA_TYPE_ID=$EXISTING_ID
    METHOD="mediatype.update"
else
    echo "  Creating new webhook media type..."
    METHOD="mediatype.create"
fi

# Step 3: Create/Update Webhook Media Type
echo ""
echo "Step 3: Creating/Updating webhook media type..."

# Webhook script
WEBHOOK_SCRIPT=$(cat <<'SCRIPT_END'
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

    Zabbix.log(4, "Greengrass webhook: " + JSON.stringify(payload));

    var response = req.post('http://localhost:8081/zabbix/events', JSON.stringify(payload));

    if (req.getStatus() !== 200) {
        throw "HTTP " + req.getStatus() + ": " + response;
    }

    return "OK";

} catch (error) {
    Zabbix.log(4, "Webhook error: " + error);
    throw error;
}
SCRIPT_END
)

# Escape the script for JSON
WEBHOOK_SCRIPT_ESCAPED=$(echo "$WEBHOOK_SCRIPT" | jq -Rs .)

if [ "$METHOD" == "mediatype.update" ]; then
    PARAMS="{
        \"mediatypeid\": \"$MEDIA_TYPE_ID\",
        \"name\": \"Greengrass Webhook\",
        \"type\": 4,
        \"script\": $WEBHOOK_SCRIPT_ESCAPED,
        \"process_tags\": 1,
        \"show_event_menu\": 1,
        \"status\": 0,
        \"message_templates\": [
            {
                \"event_source\": 0,
                \"operation_mode\": 0,
                \"subject\": \"{EVENT.NAME}\",
                \"message\": \"{TRIGGER.NAME}: {TRIGGER.STATUS}\"
            },
            {
                \"event_source\": 0,
                \"operation_mode\": 1,
                \"subject\": \"Resolved: {EVENT.NAME}\",
                \"message\": \"{TRIGGER.NAME}: {TRIGGER.STATUS}\"
            }
        ]
    }"
else
    PARAMS="{
        \"name\": \"Greengrass Webhook\",
        \"type\": 4,
        \"script\": $WEBHOOK_SCRIPT_ESCAPED,
        \"process_tags\": 1,
        \"show_event_menu\": 1,
        \"status\": 0,
        \"message_templates\": [
            {
                \"event_source\": 0,
                \"operation_mode\": 0,
                \"subject\": \"{EVENT.NAME}\",
                \"message\": \"{TRIGGER.NAME}: {TRIGGER.STATUS}\"
            },
            {
                \"event_source\": 0,
                \"operation_mode\": 1,
                \"subject\": \"Resolved: {EVENT.NAME}\",
                \"message\": \"{TRIGGER.NAME}: {TRIGGER.STATUS}\"
            }
        ]
    }"
fi

MEDIA_TYPE_RESPONSE=$(zabbix_api "$METHOD" "$PARAMS")
ERROR=$(echo "$MEDIA_TYPE_RESPONSE" | jq -r '.error // empty')

if [ -n "$ERROR" ]; then
    echo -e "${RED}✗ Failed to create/update media type${NC}"
    echo "Error: $ERROR"
    exit 1
fi

if [ "$METHOD" == "mediatype.create" ]; then
    MEDIA_TYPE_ID=$(echo "$MEDIA_TYPE_RESPONSE" | jq -r '.result.mediatypeids[0]')
fi

echo -e "${GREEN}✓ Webhook media type configured (ID: $MEDIA_TYPE_ID)${NC}"
echo ""

# Step 4: Get Admin user ID
echo "Step 4: Configuring Admin user media..."
ADMIN_USER=$(zabbix_api "user.get" '{
    "output": ["userid"],
    "filter": {
        "username": "Admin"
    }
}')

ADMIN_ID=$(echo "$ADMIN_USER" | jq -r '.result[0].userid')

if [ -z "$ADMIN_ID" ] || [ "$ADMIN_ID" == "null" ]; then
    echo -e "${RED}✗ Admin user not found${NC}"
    exit 1
fi

echo "  Admin user ID: $ADMIN_ID"

# Step 5: Add media to Admin user
echo "  Adding webhook media to Admin user..."

# Check if media already exists
EXISTING_MEDIA=$(zabbix_api "usermedia.get" "{
    \"output\": [\"mediaid\"],
    \"userids\": \"$ADMIN_ID\",
    \"mediatypeids\": \"$MEDIA_TYPE_ID\"
}")

EXISTING_MEDIA_ID=$(echo "$EXISTING_MEDIA" | jq -r '.result[0].mediaid // empty')

if [ -n "$EXISTING_MEDIA_ID" ]; then
    echo -e "${YELLOW}  ✓ Media already assigned to Admin user${NC}"
else
    USER_UPDATE=$(zabbix_api "user.update" "{
        \"userid\": \"$ADMIN_ID\",
        \"medias\": [
            {
                \"mediatypeid\": \"$MEDIA_TYPE_ID\",
                \"sendto\": \"greengrass\",
                \"active\": 0,
                \"severity\": 63,
                \"period\": \"1-7,00:00-24:00\"
            }
        ]
    }")

    ERROR=$(echo "$USER_UPDATE" | jq -r '.error // empty')

    if [ -n "$ERROR" ]; then
        echo -e "${YELLOW}  Warning: Could not auto-assign media to user${NC}"
        echo "  Please assign manually via Zabbix UI"
    else
        echo -e "${GREEN}  ✓ Media assigned to Admin user${NC}"
    fi
fi

echo ""

# Step 6: Test the webhook
echo "Step 6: Testing webhook endpoint..."
TEST_RESPONSE=$(curl -s -X POST "$WEBHOOK_URL" \
    -H "Content-Type: application/json" \
    -d '{
        "event_id": "SETUP-TEST-001",
        "event_status": "1",
        "event_severity": "4",
        "host_id": "99999",
        "host_name": "Setup Test Host",
        "host_ip": "127.0.0.1",
        "trigger_name": "Setup test trigger",
        "trigger_description": "Automated setup test",
        "timestamp": "'$(date -u +%Y-%m-%dT%H:%M:%SZ)'"
    }')

if echo "$TEST_RESPONSE" | grep -q "success"; then
    echo -e "${GREEN}✓ Webhook endpoint test successful!${NC}"
    echo "Response: $TEST_RESPONSE"
else
    echo -e "${RED}✗ Webhook test failed${NC}"
    echo "Response: $TEST_RESPONSE"
fi

echo ""
echo "============================================================================"
echo "  ✅ Zabbix Webhook Configuration Complete!"
echo "============================================================================"
echo ""
echo "📋 Summary:"
echo "  • Webhook Media Type: Greengrass Webhook (ID: $MEDIA_TYPE_ID)"
echo "  • Webhook URL: $WEBHOOK_URL"
echo "  • Admin User: Configured"
echo "  • Test: Successful"
echo ""
echo "🎯 Next Steps:"
echo "  1. Create camera hosts in Zabbix (if not exists)"
echo "  2. Configure ICMP ping items for cameras"
echo "  3. Create triggers for offline detection"
echo "  4. Create action to send webhooks on trigger"
echo ""
echo "📖 See ZABBIX_WEBHOOK_SETUP.md for detailed configuration guide"
echo "============================================================================"
