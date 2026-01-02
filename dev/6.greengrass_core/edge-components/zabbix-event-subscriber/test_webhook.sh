#!/bin/bash
# ============================================================================
# Zabbix Event Subscriber - Webhook Test Script
# ============================================================================
# Purpose: Test the webhook server by sending simulated Zabbix events
# Usage: ./test_webhook.sh

WEBHOOK_URL="${WEBHOOK_URL:-http://localhost:8081}"

echo "================================================================"
echo "  Testing Zabbix Event Subscriber Webhook Server"
echo "================================================================"
echo "  Webhook URL: $WEBHOOK_URL"
echo "================================================================"

# Test 1: Health Check
echo
echo "[TEST 1] Health Check..."
curl -s -X GET "$WEBHOOK_URL/health" | jq '.'
echo

# Test 2: Send Camera Offline Event (PROBLEM)
echo "[TEST 2] Sending camera offline event (PROBLEM)..."
curl -s -X POST "$WEBHOOK_URL/zabbix/events" \
  -H "Content-Type: application/json" \
  -d '{
    "event_id": "10001",
    "event_status": "1",
    "event_severity": "4",
    "host_id": "10770",
    "host_name": "IP Camera 01",
    "host_ip": "192.168.1.11",
    "trigger_description": "Camera is offline - no response to ping",
    "timestamp": "'"$(date -u +%Y-%m-%dT%H:%M:%SZ)"'"
  }' | jq '.'
echo

# Test 3: Send Camera Online Event (RECOVERY)
echo "[TEST 3] Sending camera online event (RECOVERY)..."
sleep 2
curl -s -X POST "$WEBHOOK_URL/zabbix/events" \
  -H "Content-Type: application/json" \
  -d '{
    "event_id": "10002",
    "event_status": "0",
    "event_severity": "0",
    "host_id": "10770",
    "host_name": "IP Camera 01",
    "host_ip": "192.168.1.11",
    "trigger_description": "Camera is online",
    "timestamp": "'"$(date -u +%Y-%m-%dT%H:%M:%SZ)"'"
  }' | jq '.'
echo

# Test 4: List Recent Events
echo "[TEST 4] Listing recent incidents..."
curl -s -X GET "$WEBHOOK_URL/zabbix/events" | jq '.'
echo

echo "================================================================"
echo "  ✅ Webhook tests completed"
echo "================================================================"
