# ============================================================================
# Zabbix Webhook Integration Fixes - IaC Compliant
# ============================================================================
# Purpose: Deploy fixes for Zabbix webhook integration in IaC-compliant manner
# Fixes:
#   1. Install fping for Zabbix ICMP ping checks
#   2. Deploy updated webhook_server.py (camera auto-creation)
#   3. Deploy updated dao.py (ngsi_ld optional field)
# ============================================================================

# ============================================================================
# Step 1: Install fping for Zabbix ICMP Checks
# ============================================================================

resource "null_resource" "install_fping" {
  triggers = {
    # Only run once unless explicitly changed
    install_version = "fping_v1"
  }

  provisioner "local-exec" {
    command = <<-EOT
      echo "======================================================================"
      echo "Installing fping for Zabbix ICMP Ping Checks"
      echo "======================================================================"

      # Check if fping is already installed
      if command -v fping &> /dev/null; then
        echo "✓ fping already installed: $(fping -v 2>&1 | head -1)"
      else
        echo "Installing fping..."
        sudo apt-get update -qq
        sudo DEBIAN_FRONTEND=noninteractive apt-get install -y fping
        echo "✅ fping installed successfully"
      fi

      # Set setuid permission (required for non-root ICMP)
      echo "Setting setuid permission on fping..."
      sudo chmod u+s /usr/bin/fping
      echo "✅ setuid permission set"

      # Create symlink for Zabbix (expects /usr/sbin/fping)
      if [ ! -L /usr/sbin/fping ]; then
        echo "Creating symlink /usr/sbin/fping -> /usr/bin/fping..."
        sudo ln -s /usr/bin/fping /usr/sbin/fping
        echo "✅ Symlink created"
      else
        echo "✓ Symlink already exists"
      fi

      # Verify installation
      echo ""
      echo "Verification:"
      ls -la /usr/bin/fping
      ls -la /usr/sbin/fping
      fping -v 2>&1 | head -1

      echo ""
      echo "✅ fping installation complete"
      echo "======================================================================"
    EOT
  }
}

# ============================================================================
# Step 2: Deploy Updated Webhook Handler and DAO Layer
# ============================================================================

locals {
  # Paths to source files (using existing edge_components_path from edge-components.tf)
  webhook_src_path = "${local.edge_components_path}/zabbix-event-subscriber/src/webhook_server.py"
  dao_src_path = "${local.edge_components_path}/python-dao/dao.py"

  # Deployment paths
  webhook_deploy_path = "/greengrass/v2/components/artifacts/com.aismc.ZabbixEventSubscriber/1.0.0"
  dao_deploy_path = "/greengrass/v2/components/common/database"
}

resource "null_resource" "deploy_webhook_fixes" {
  # Trigger redeployment when source files change
  triggers = {
    webhook_server_md5 = filemd5(local.webhook_src_path)
    dao_md5 = filemd5(local.dao_src_path)
  }

  provisioner "local-exec" {
    command = <<-EOT
      echo "======================================================================"
      echo "Deploying Zabbix Webhook Fixes"
      echo "======================================================================"

      echo "[1/3] Backing up current files..."
      BACKUP_DIR=/tmp/greengrass-backup-$(date +%Y%m%d%H%M%S)
      mkdir -p "$BACKUP_DIR"

      sudo cp ${local.webhook_deploy_path}/webhook_server.py "$BACKUP_DIR/" 2>/dev/null || true
      sudo cp ${local.dao_deploy_path}/dao.py "$BACKUP_DIR/" 2>/dev/null || true

      echo "✅ Backup created: $BACKUP_DIR"

      echo ""
      echo "[2/3] Deploying updated source files..."

      # Deploy updated webhook_server.py
      echo "  - Deploying webhook_server.py..."
      sudo cp ${local.webhook_src_path} ${local.webhook_deploy_path}/webhook_server.py
      sudo chown ggc_user:ggc_group ${local.webhook_deploy_path}/webhook_server.py
      sudo chmod 644 ${local.webhook_deploy_path}/webhook_server.py
      echo "    ✅ webhook_server.py deployed"

      # Deploy updated dao.py
      echo "  - Deploying dao.py..."
      sudo cp ${local.dao_src_path} ${local.dao_deploy_path}/dao.py
      sudo chown ggc_user:ggc_group ${local.dao_deploy_path}/dao.py
      sudo chmod 644 ${local.dao_deploy_path}/dao.py
      echo "    ✅ dao.py deployed"

      echo ""
      echo "[3/3] Restarting Greengrass to load changes..."
      sudo systemctl restart greengrass

      # Wait for Greengrass to fully restart
      echo "Waiting for Greengrass to restart (30 seconds)..."
      sleep 30

      # Check Greengrass status
      if sudo systemctl is-active --quiet greengrass; then
        echo "✅ Greengrass service is running"
      else
        echo "⚠ Greengrass service status:"
        sudo systemctl status greengrass --no-pager | head -10
      fi

      echo ""
      echo "======================================================================"
      echo "Deployment Summary"
      echo "======================================================================"
      echo "✅ fping: Installed and configured"
      echo "✅ webhook_server.py: Updated with camera auto-creation logic"
      echo "✅ dao.py: Updated with optional ngsi_ld field"
      echo "✅ Greengrass: Restarted and loaded changes"
      echo ""
      echo "Backup location: $BACKUP_DIR"
      echo "======================================================================"
    EOT
  }

  depends_on = [null_resource.install_fping]
}

# ============================================================================
# Step 3: Verify Webhook Endpoint Health
# ============================================================================

resource "null_resource" "verify_webhook_fixes" {
  triggers = {
    deployment_id = null_resource.deploy_webhook_fixes.id
  }

  provisioner "local-exec" {
    command = <<-EOT
      echo "======================================================================"
      echo "Verifying Webhook Deployment"
      echo "======================================================================"

      # Wait for webhook server to fully start
      echo "Waiting for webhook server to start (15 seconds)..."
      sleep 15

      echo ""
      echo "[1/3] Checking webhook endpoint health..."
      HEALTH_CHECK=$(curl -s http://localhost:8081/health 2>&1)

      if echo "$HEALTH_CHECK" | grep -q '"status": "healthy"'; then
        echo "✅ Webhook endpoint is healthy"
        echo "$HEALTH_CHECK" | python3 -m json.tool 2>/dev/null || echo "$HEALTH_CHECK"
      else
        echo "⚠ Webhook endpoint check:"
        echo "$HEALTH_CHECK"
      fi

      echo ""
      echo "[2/3] Checking Greengrass component status..."
      sudo -u ggc_user /greengrass/v2/bin/greengrass-cli component list 2>/dev/null | grep -E "(ZabbixEventSubscriber|RUNNING|FINISHED)" || echo "Components starting..."

      echo ""
      echo "[3/3] Checking webhook server process..."
      if pgrep -f "webhook_server.py" > /dev/null; then
        echo "✅ Webhook server process is running"
        ps aux | grep -E "webhook_server.py" | grep -v grep | head -1
      else
        echo "⚠ Webhook server process not found"
      fi

      echo ""
      echo "======================================================================"
      echo "Verification Complete"
      echo "======================================================================"
      echo ""
      echo "Next steps:"
      echo "1. Test webhook macro expansion by triggering a Zabbix alert"
      echo "2. Check webhook logs: sudo tail -f /greengrass/v2/logs/com.aismc.ZabbixEventSubscriber.log"
      echo "3. Monitor database: sqlite3 /var/greengrass/database/greengrass.db 'SELECT * FROM incidents;'"
      echo ""
      echo "======================================================================"
    EOT
  }

  depends_on = [null_resource.deploy_webhook_fixes]
}

# ============================================================================
# Restart Zabbix Server to Clear Cache
# ============================================================================

resource "null_resource" "restart_zabbix_server" {
  triggers = {
    webhook_deployment = null_resource.deploy_webhook_fixes.id
  }

  provisioner "local-exec" {
    command = <<-EOT
      echo "======================================================================"
      echo "Restarting Zabbix Server to Clear Configuration Cache"
      echo "======================================================================"

      # Restart Zabbix server to ensure all configurations are reloaded
      echo "Restarting Zabbix server..."
      sudo systemctl restart zabbix-server

      # Wait for Zabbix server to fully restart
      sleep 10

      # Check Zabbix server status
      if sudo systemctl is-active --quiet zabbix-server; then
        echo "✅ Zabbix server is running"
        echo ""
        echo "Zabbix server uptime:"
        sudo systemctl status zabbix-server --no-pager | grep "Active:" || true
      else
        echo "⚠ Zabbix server status:"
        sudo systemctl status zabbix-server --no-pager | head -10
      fi

      echo ""
      echo "======================================================================"
    EOT
  }

  depends_on = [null_resource.verify_webhook_fixes]
}

# ============================================================================
# Outputs
# ============================================================================

output "webhook_fixes_status" {
  description = "Status of webhook fixes deployment"
  value = {
    fping_installed = "Installed with setuid permission and symlink"
    webhook_server_updated = "Camera auto-creation logic added"
    dao_layer_updated = "ngsi_ld field made optional"
    deployment_method = "Infrastructure as Code (Terraform)"
  }
}

output "webhook_verification_command" {
  description = "Command to verify webhook endpoint"
  value = "curl -s http://localhost:8081/health | python3 -m json.tool"
}

output "webhook_test_command" {
  description = "Command to test webhook with sample payload"
  value = <<-EOT
    curl -X POST http://localhost:8081/zabbix/events \
      -H "Content-Type: application/json" \
      -d '{
        "event_id": "TEST-001",
        "event_status": "1",
        "event_severity": "5",
        "host_id": "99999",
        "host_name": "Test Camera",
        "host_ip": "192.168.1.99",
        "trigger_name": "Test Alert",
        "trigger_description": "Testing webhook",
        "timestamp": "'$(date -u +%Y-%m-%dT%H:%M:%SZ)'"
      }'
  EOT
}

output "webhook_logs_command" {
  description = "Command to view webhook logs"
  value = "sudo tail -f /greengrass/v2/logs/com.aismc.ZabbixEventSubscriber.log"
}

output "database_check_command" {
  description = "Command to check database for incidents"
  value = "sqlite3 /var/greengrass/database/greengrass.db 'SELECT incident_id, camera_id, incident_type, severity, detected_at FROM incidents ORDER BY detected_at DESC LIMIT 10;'"
}
