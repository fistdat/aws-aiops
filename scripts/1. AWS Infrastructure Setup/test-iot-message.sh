#!/bin/bash
set -e

# Test IoT Message Publishing Script
# Usage: ./scripts/test-iot-message.sh <topic> <message-file>

TOPIC=${1:-"cameras/site-001/incidents"}
MESSAGE_FILE=${2:-""}
REGION="ap-southeast-1"

GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m'

function log_info() {
    echo -e "${GREEN}[INFO]${NC} $1"
}

if [ -z "$MESSAGE_FILE" ]; then
    # Create a test incident message
    MESSAGE='{
  "incident_id": "test-'$(date +%s)'",
  "site_id": "site-001",
  "entity_id": "camera-001",
  "incident_type": "camera_offline",
  "priority": "critical",
  "timestamp": "'$(date -u +%Y-%m-%dT%H:%M:%SZ)'",
  "description": "Test incident message",
  "@context": "https://uri.etsi.org/ngsi-ld/v1/ngsi-ld-core-context.jsonld",
  "type": "Incident"
}'
    echo "$MESSAGE" > /tmp/test-message.json
    MESSAGE_FILE="/tmp/test-message.json"
    log_info "Created test message: ${MESSAGE_FILE}"
fi

echo "=================================="
echo "Publishing Test Message to IoT Core"
echo "=================================="
echo "Topic: ${TOPIC}"
echo "Message File: ${MESSAGE_FILE}"
echo "Region: ${REGION}"
echo "=================================="

cat ${MESSAGE_FILE}

echo ""
log_info "Publishing message..."

aws iot-data publish \
  --topic ${TOPIC} \
  --payload file://${MESSAGE_FILE} \
  --region ${REGION}

log_info "Message published successfully!"

echo ""
echo "=================================="
log_info "Next steps:"
echo "  1. Check CloudWatch Logs for IoT Rules processing"
echo "  2. Query DynamoDB to verify message stored:"
echo "     aws dynamodb scan --table-name aismc-dev-camera-incidents --limit 10"
echo "  3. Check SNS email if message matched critical alert rule"
echo "=================================="
