#!/bin/bash
# Verification script for ZabbixEventSubscriber component

echo "================================================================"
echo "  ZabbixEventSubscriber Component Verification"
echo "================================================================"

echo ""
echo "[1] Checking component status..."
sudo /greengrass/v2/bin/greengrass-cli component list | grep -A 5 ZabbixEventSubscriber || echo "Component not found in list"

echo ""
echo "[2] Checking component logs..."
LOG_FILE="/greengrass/v2/logs/com.aismc.ZabbixEventSubscriber.log"
if [ -f "$LOG_FILE" ]; then
  echo "✅ Log file exists: $LOG_FILE"
  echo "Recent logs:"
  sudo tail -30 "$LOG_FILE"
else
  echo "⚠️  Log file not found yet: $LOG_FILE"
  echo "Checking all component logs:"
  sudo ls -la /greengrass/v2/logs/ | grep -i zabbix || echo "No Zabbix-related logs found"
fi

echo ""
echo "[3] Checking if webhook server is listening on port 8081..."
if sudo lsof -i :8081 > /dev/null 2>&1; then
  echo "✅ Port 8081 is active"
  sudo lsof -i :8081
else
  echo "❌ Port 8081 is not listening"
  echo "Checking all listening ports:"
  sudo netstat -tlnp | grep python3 || echo "No Python processes listening"
fi

echo ""
echo "[4] Testing health endpoint..."
sleep 2
HEALTH=$(curl -s -f http://localhost:8081/health 2>/dev/null)
if [ $? -eq 0 ]; then
  echo "✅ Health check successful"
  echo "$HEALTH" | jq '.' 2>/dev/null || echo "$HEALTH"
else
  echo "❌ Health check failed - server may still be starting"
  echo "Retrying in 5 seconds..."
  sleep 5
  curl -s -f http://localhost:8081/health 2>/dev/null | jq '.' 2>/dev/null || echo "Still not responding"
fi

echo ""
echo "[5] Checking artifact deployment..."
ARTIFACT_PATH="/greengrass/v2/components/artifacts/com.aismc.ZabbixEventSubscriber/1.0.0"
if [ -f "$ARTIFACT_PATH/webhook_server.py" ]; then
  echo "✅ webhook_server.py deployed to $ARTIFACT_PATH"
else
  echo "❌ webhook_server.py not found at $ARTIFACT_PATH"
fi

if [ -f "$ARTIFACT_PATH/requirements.txt" ]; then
  echo "✅ requirements.txt deployed"
else
  echo "❌ requirements.txt not found"
fi

echo ""
echo "[6] Checking recipe deployment..."
RECIPE_PATH="/greengrass/v2/components/recipes/com.aismc.ZabbixEventSubscriber-1.0.0.yaml"
if [ -f "$RECIPE_PATH" ]; then
  echo "✅ Recipe deployed to $RECIPE_PATH"
else
  echo "❌ Recipe not found at $RECIPE_PATH"
fi

echo ""
echo "================================================================"
echo "  Verification Complete"
echo "================================================================"
echo ""
echo "To view live logs:"
echo "  sudo tail -f /greengrass/v2/logs/com.aismc.ZabbixEventSubscriber.log"
echo ""
echo "To test webhook:"
echo "  cd ./edge-components/zabbix-event-subscriber"
echo "  ./test_webhook.sh"
echo ""
