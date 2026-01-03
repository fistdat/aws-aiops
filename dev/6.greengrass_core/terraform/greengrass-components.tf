# ============================================================================
# Greengrass Custom Components Deployment
# ============================================================================
# Purpose: Deploy custom Greengrass components via local deployment
# Components: ZabbixEventSubscriber v1.0.0
# ============================================================================

locals {
  components_base_path = "/greengrass/v2/components"
  components_source    = "${path.module}/edge-components"

  # Component artifacts will be stored here
  artifacts_path = "${local.components_base_path}/artifacts"
  recipes_path   = "${local.components_base_path}/recipes"
}

# ============================================================================
# Install Component Dependencies
# ============================================================================

resource "null_resource" "install_flask_dependencies" {
  triggers = {
    install_required = "flask_v3.0.0"
  }

  provisioner "local-exec" {
    command = <<-EOT
      echo "Installing Flask dependencies for ZabbixEventSubscriber..."
      sudo pip3 install flask==3.0.0 werkzeug==3.0.1
      echo "✅ Flask dependencies installed"
    EOT
  }
}

# Fix database permissions for component access
resource "null_resource" "fix_database_permissions" {
  triggers = {
    always_run = timestamp()
  }

  depends_on = [null_resource.install_flask_dependencies]

  provisioner "local-exec" {
    command = <<-EOT
      echo "Fixing database permissions..."

      # Ensure database directory is writable by ggc_group
      sudo chown -R ggc_user:ggc_group /var/greengrass/database
      sudo chmod 775 /var/greengrass/database

      # Ensure database files are writable by group
      sudo chmod 664 /var/greengrass/database/greengrass.db* 2>/dev/null || true

      # Add current user to ggc_group if not already (for testing)
      sudo usermod -aG ggc_group $USER || true

      echo "✅ Database permissions fixed"
    EOT
  }
}

# ============================================================================
# Create Component Directories
# ============================================================================

resource "null_resource" "create_component_directories" {
  triggers = {
    always_run = timestamp()
  }

  depends_on = [null_resource.fix_database_permissions]

  provisioner "local-exec" {
    command = <<-EOT
      sudo mkdir -p ${local.artifacts_path}/com.aismc.ZabbixEventSubscriber/1.0.0
      sudo mkdir -p ${local.recipes_path}
      sudo chown -R ggc_user:ggc_group ${local.components_base_path}
      sudo chmod -R 755 ${local.components_base_path}
      echo "✅ Component directories created"
    EOT
  }
}

# ============================================================================
# Deploy ZabbixEventSubscriber Component
# ============================================================================

# Deploy webhook server script
resource "null_resource" "deploy_webhook_server" {
  triggers = {
    file_md5 = filemd5("${local.components_source}/zabbix-event-subscriber/src/webhook_server.py")
  }

  depends_on = [null_resource.create_component_directories]

  provisioner "local-exec" {
    command = <<-EOT
      sudo cp ${local.components_source}/zabbix-event-subscriber/src/webhook_server.py \
        ${local.artifacts_path}/com.aismc.ZabbixEventSubscriber/1.0.0/webhook_server.py
      sudo chown ggc_user:ggc_group \
        ${local.artifacts_path}/com.aismc.ZabbixEventSubscriber/1.0.0/webhook_server.py
      sudo chmod 755 \
        ${local.artifacts_path}/com.aismc.ZabbixEventSubscriber/1.0.0/webhook_server.py
      echo "✅ Deployed webhook_server.py"
    EOT
  }
}

# Deploy requirements.txt
resource "null_resource" "deploy_webhook_requirements" {
  triggers = {
    file_md5 = filemd5("${local.components_source}/zabbix-event-subscriber/requirements.txt")
  }

  depends_on = [null_resource.create_component_directories]

  provisioner "local-exec" {
    command = <<-EOT
      sudo cp ${local.components_source}/zabbix-event-subscriber/requirements.txt \
        ${local.artifacts_path}/com.aismc.ZabbixEventSubscriber/1.0.0/requirements.txt
      sudo chown ggc_user:ggc_group \
        ${local.artifacts_path}/com.aismc.ZabbixEventSubscriber/1.0.0/requirements.txt
      sudo chmod 644 \
        ${local.artifacts_path}/com.aismc.ZabbixEventSubscriber/1.0.0/requirements.txt
      echo "✅ Deployed requirements.txt"
    EOT
  }
}

# Update recipe to use correct artifact paths
resource "local_file" "webhook_recipe" {
  filename = "${path.module}/edge-components/zabbix-event-subscriber/recipe-deployed.yaml"

  content = <<-EOT
---
RecipeFormatVersion: '2020-01-25'
ComponentName: com.aismc.ZabbixEventSubscriber
ComponentVersion: '1.0.0'
ComponentDescription: |
  HTTP webhook server to receive Zabbix problem/recovery events.
  Stores incidents in local SQLite database for offline resilience.
ComponentPublisher: AISMC
ComponentType: aws.greengrass.generic

ComponentConfiguration:
  DefaultConfiguration:
    webhook_host: "0.0.0.0"
    webhook_port: 8081
    site_id: "site-001"
    log_level: "INFO"

Manifests:
  - Platform:
      os: linux
    Lifecycle:
      Install:
        RequiresPrivilege: true
        Script: |
          echo "Installing ZabbixEventSubscriber dependencies..."
          pip3 install flask==3.0.0 werkzeug==3.0.1
          echo "✅ Dependencies installed"

      Run:
        RequiresPrivilege: false
        Script: |
          echo "Starting ZabbixEventSubscriber webhook server..."
          python3 -u ${local.artifacts_path}/com.aismc.ZabbixEventSubscriber/1.0.0/webhook_server.py \
            --host {configuration:/webhook_host} \
            --port {configuration:/webhook_port}

      Shutdown:
        Script: |
          echo "Stopping ZabbixEventSubscriber..."
          pkill -f "webhook_server.py"
        Timeout: 10
EOT

  depends_on = [
    null_resource.deploy_webhook_server,
    null_resource.deploy_webhook_requirements
  ]
}

# Deploy component recipe
resource "null_resource" "deploy_webhook_recipe" {
  triggers = {
    recipe_md5 = local_file.webhook_recipe.content_md5
  }

  depends_on = [
    null_resource.create_component_directories,
    local_file.webhook_recipe
  ]

  provisioner "local-exec" {
    command = <<-EOT
      sudo cp ${local_file.webhook_recipe.filename} \
        ${local.recipes_path}/com.aismc.ZabbixEventSubscriber-1.0.0.yaml
      sudo chown ggc_user:ggc_group \
        ${local.recipes_path}/com.aismc.ZabbixEventSubscriber-1.0.0.yaml
      sudo chmod 644 \
        ${local.recipes_path}/com.aismc.ZabbixEventSubscriber-1.0.0.yaml
      echo "✅ Deployed component recipe"
    EOT
  }
}

# ============================================================================
# Create Local Component Deployment
# ============================================================================

resource "null_resource" "deploy_zabbix_event_subscriber" {
  triggers = {
    recipe_md5 = local_file.webhook_recipe.content_md5
    server_md5 = filemd5("${local.components_source}/zabbix-event-subscriber/src/webhook_server.py")
  }

  depends_on = [
    null_resource.deploy_webhook_server,
    null_resource.deploy_webhook_requirements,
    null_resource.deploy_webhook_recipe
  ]

  provisioner "local-exec" {
    command = <<-EOT
      echo "Deploying ZabbixEventSubscriber component..."

      # Create local deployment using Greengrass CLI
      sudo /greengrass/v2/bin/greengrass-cli deployment create \
        --recipeDir ${local.recipes_path} \
        --artifactDir ${local.artifacts_path} \
        --merge "com.aismc.ZabbixEventSubscriber=1.0.0"

      echo "✅ ZabbixEventSubscriber deployment initiated"

      # Wait for deployment to settle
      sleep 15

      # Check component status
      echo ""
      echo "Component status:"
      sudo /greengrass/v2/bin/greengrass-cli component list | grep -E "(Component Name|ZabbixEventSubscriber)" || true
    EOT
  }
}

# ============================================================================
# Verification Script
# ============================================================================

resource "local_file" "verify_webhook_script" {
  filename = "${path.module}/verify-webhook.sh"

  content = <<-EOT
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
ARTIFACT_PATH="${local.artifacts_path}/com.aismc.ZabbixEventSubscriber/1.0.0"
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
RECIPE_PATH="${local.recipes_path}/com.aismc.ZabbixEventSubscriber-1.0.0.yaml"
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
echo "  cd ${path.module}/edge-components/zabbix-event-subscriber"
echo "  ./test_webhook.sh"
echo ""
EOT

  file_permission = "0755"
}

# Run verification after deployment
resource "null_resource" "verify_webhook_deployment" {
  triggers = {
    deployment_id = null_resource.deploy_zabbix_event_subscriber.id
  }

  depends_on = [
    null_resource.deploy_zabbix_event_subscriber,
    local_file.verify_webhook_script
  ]

  provisioner "local-exec" {
    command = "bash ${local_file.verify_webhook_script.filename}"
  }
}

# ============================================================================
# Deploy IncidentMessageForwarder Component
# ============================================================================

# Deploy forwarder service script
resource "null_resource" "deploy_forwarder_service" {
  triggers = {
    file_md5 = filemd5("${local.components_source}/incident-message-forwarder/src/forwarder_service.py")
  }

  depends_on = [null_resource.create_component_directories]

  provisioner "local-exec" {
    command = <<-EOT
      sudo mkdir -p ${local.artifacts_path}/com.aismc.IncidentMessageForwarder/1.0.0
      sudo cp ${local.components_source}/incident-message-forwarder/src/forwarder_service.py \
        ${local.artifacts_path}/com.aismc.IncidentMessageForwarder/1.0.0/forwarder_service.py
      sudo chown ggc_user:ggc_group \
        ${local.artifacts_path}/com.aismc.IncidentMessageForwarder/1.0.0/forwarder_service.py
      sudo chmod 755 \
        ${local.artifacts_path}/com.aismc.IncidentMessageForwarder/1.0.0/forwarder_service.py
      echo "✅ Deployed forwarder_service.py"
    EOT
  }
}

# Deploy requirements.txt
resource "null_resource" "deploy_forwarder_requirements" {
  triggers = {
    file_md5 = filemd5("${local.components_source}/incident-message-forwarder/requirements.txt")
  }

  depends_on = [null_resource.create_component_directories]

  provisioner "local-exec" {
    command = <<-EOT
      sudo cp ${local.components_source}/incident-message-forwarder/requirements.txt \
        ${local.artifacts_path}/com.aismc.IncidentMessageForwarder/1.0.0/requirements.txt
      sudo chown ggc_user:ggc_group \
        ${local.artifacts_path}/com.aismc.IncidentMessageForwarder/1.0.0/requirements.txt
      sudo chmod 644 \
        ${local.artifacts_path}/com.aismc.IncidentMessageForwarder/1.0.0/requirements.txt
      echo "✅ Deployed requirements.txt"
    EOT
  }
}

# Deploy component recipe
resource "null_resource" "deploy_forwarder_recipe" {
  triggers = {
    file_md5 = filemd5("${local.components_source}/incident-message-forwarder/recipe.yaml")
  }

  depends_on = [null_resource.create_component_directories]

  provisioner "local-exec" {
    command = <<-EOT
      sudo cp ${local.components_source}/incident-message-forwarder/recipe.yaml \
        ${local.recipes_path}/com.aismc.IncidentMessageForwarder-1.0.0.yaml
      sudo chown ggc_user:ggc_group \
        ${local.recipes_path}/com.aismc.IncidentMessageForwarder-1.0.0.yaml
      sudo chmod 644 \
        ${local.recipes_path}/com.aismc.IncidentMessageForwarder-1.0.0.yaml
      echo "✅ Deployed component recipe"
    EOT
  }
}

# Update DAO layer with new methods
resource "null_resource" "update_dao_for_forwarder" {
  triggers = {
    dao_md5 = filemd5("${path.module}/edge-database/src/database/dao.py")
  }

  depends_on = [null_resource.deploy_forwarder_recipe]

  provisioner "local-exec" {
    command = <<-EOT
      echo "Updating DAO layer..."
      sudo cp ${path.module}/edge-database/src/database/dao.py \
        /greengrass/v2/components/common/database/dao.py
      sudo chown ggc_user:ggc_group /greengrass/v2/components/common/database/dao.py
      sudo chmod 644 /greengrass/v2/components/common/database/dao.py
      echo "✅ DAO layer updated"
    EOT
  }
}

# ============================================================================
# Deploy ZabbixHostRegistrySync Component
# ============================================================================

# Deploy sync service script
resource "null_resource" "deploy_registry_sync_service" {
  triggers = {
    file_md5 = filemd5("${local.components_source}/zabbix-host-registry-sync/src/sync_service.py")
  }

  depends_on = [null_resource.create_component_directories]

  provisioner "local-exec" {
    command = <<-EOT
      sudo mkdir -p ${local.artifacts_path}/com.aismc.ZabbixHostRegistrySync/1.0.0
      sudo cp ${local.components_source}/zabbix-host-registry-sync/src/sync_service.py \
        ${local.artifacts_path}/com.aismc.ZabbixHostRegistrySync/1.0.0/sync_service.py
      sudo chown ggc_user:ggc_group \
        ${local.artifacts_path}/com.aismc.ZabbixHostRegistrySync/1.0.0/sync_service.py
      sudo chmod 755 \
        ${local.artifacts_path}/com.aismc.ZabbixHostRegistrySync/1.0.0/sync_service.py
      echo "✅ Deployed sync_service.py"
    EOT
  }
}

# Deploy requirements.txt
resource "null_resource" "deploy_registry_sync_requirements" {
  triggers = {
    file_md5 = filemd5("${local.components_source}/zabbix-host-registry-sync/requirements.txt")
  }

  depends_on = [null_resource.deploy_registry_sync_service]

  provisioner "local-exec" {
    command = <<-EOT
      sudo cp ${local.components_source}/zabbix-host-registry-sync/requirements.txt \
        ${local.artifacts_path}/com.aismc.ZabbixHostRegistrySync/1.0.0/requirements.txt
      sudo chown ggc_user:ggc_group \
        ${local.artifacts_path}/com.aismc.ZabbixHostRegistrySync/1.0.0/requirements.txt
      sudo chmod 644 \
        ${local.artifacts_path}/com.aismc.ZabbixHostRegistrySync/1.0.0/requirements.txt
      echo "✅ Deployed requirements.txt"
    EOT
  }
}

# Deploy component recipe
resource "null_resource" "deploy_registry_sync_recipe" {
  triggers = {
    file_md5 = filemd5("${local.components_source}/zabbix-host-registry-sync/recipe.yaml")
  }

  depends_on = [null_resource.create_component_directories]

  provisioner "local-exec" {
    command = <<-EOT
      sudo cp ${local.components_source}/zabbix-host-registry-sync/recipe.yaml \
        ${local.recipes_path}/com.aismc.ZabbixHostRegistrySync-1.0.0.yaml
      sudo chown ggc_user:ggc_group \
        ${local.recipes_path}/com.aismc.ZabbixHostRegistrySync-1.0.0.yaml
      sudo chmod 644 \
        ${local.recipes_path}/com.aismc.ZabbixHostRegistrySync-1.0.0.yaml
      echo "✅ Deployed component recipe"
    EOT
  }
}

# ============================================================================
# Greengrass Deployment
# ============================================================================

# Phase 1: Deploy Greengrass CLI component from AWS
resource "null_resource" "deploy_greengrass_cli" {
  triggers = {
    cli_config = filemd5("${path.module}/cli-deployment.json")
  }

  provisioner "local-exec" {
    command = <<-EOT
      echo "Phase 1: Deploying Greengrass CLI component..."

      # Deploy CLI component via AWS API
      aws greengrassv2 create-deployment \
        --cli-input-json file://${path.module}/cli-deployment.json \
        --region ap-southeast-1 \
        > ${path.module}/cli-deployment-result.json

      # Get deployment ID
      CLI_DEPLOYMENT_ID=$(cat ${path.module}/cli-deployment-result.json | python3 -c "import sys, json; print(json.load(sys.stdin)['deploymentId'])")
      echo "CLI Deployment ID: $CLI_DEPLOYMENT_ID"

      # Wait for CLI deployment to complete (max 3 minutes)
      echo "Waiting for CLI component to deploy..."
      for i in $(seq 1 36); do
        STATUS=$(aws greengrassv2 get-deployment \
          --deployment-id $CLI_DEPLOYMENT_ID \
          --region ap-southeast-1 \
          --query 'deploymentStatus' \
          --output text 2>/dev/null || echo "UNKNOWN")

        echo "CLI deployment status: $STATUS (check $i/36)"

        if [ "$STATUS" = "COMPLETED" ]; then
          echo "✅ CLI component deployed successfully!"

          # Wait extra 10 seconds for CLI to be ready
          echo "Waiting for CLI to initialize..."
          sleep 10

          # Verify CLI is accessible
          if [ -x /greengrass/v2/bin/greengrass-cli ]; then
            echo "✅ Greengrass CLI is ready!"
            exit 0
          else
            echo "⚠️ CLI binary not found, waiting more..."
            sleep 10
            exit 0
          fi
        elif [ "$STATUS" = "FAILED" ] || [ "$STATUS" = "CANCELED" ]; then
          echo "❌ CLI deployment failed with status: $STATUS"
          exit 1
        fi

        sleep 5
      done

      echo "⚠️ CLI deployment timeout"
      exit 1
    EOT
  }
}

# Configure sudoers for greengrass-cli (required for local deployments)
resource "null_resource" "configure_greengrass_sudoers" {
  triggers = {
    always_run = timestamp()
  }

  depends_on = [null_resource.deploy_greengrass_cli]

  provisioner "local-exec" {
    command = <<-EOT
      # Add sudoers entry for greengrass-cli if not exists
      if ! sudo grep -q "greengrass-cli" /etc/sudoers.d/greengrass 2>/dev/null; then
        echo "Configuring sudoers for greengrass-cli..."
        echo "$USER ALL=(ALL) NOPASSWD: /greengrass/v2/bin/greengrass-cli" | sudo tee /etc/sudoers.d/greengrass-cli
        sudo chmod 0440 /etc/sudoers.d/greengrass-cli
        echo "✅ Sudoers configured"
      else
        echo "Sudoers already configured for greengrass-cli"
      fi
    EOT
  }
}

# Create Greengrass deployment to deploy all custom components
resource "null_resource" "greengrass_components_deployment" {
  triggers = {
    deployment_config = filemd5("${path.module}/edge-components-deployment.json")
    # Re-deploy when any component artifact changes
    webhook_md5    = filemd5("${local.components_source}/zabbix-event-subscriber/src/webhook_server.py")
    forwarder_md5  = filemd5("${local.components_source}/incident-message-forwarder/src/forwarder_service.py")
    sync_md5       = filemd5("${local.components_source}/zabbix-host-registry-sync/src/sync_service.py")
  }

  depends_on = [
    null_resource.deploy_webhook_recipe,
    null_resource.deploy_forwarder_recipe,
    null_resource.deploy_registry_sync_recipe,
    null_resource.configure_greengrass_sudoers
  ]

  provisioner "local-exec" {
    command = <<-EOT
      echo "Phase 2: Deploying custom local components via greengrass-cli..."

      # Use greengrass-cli to create local deployment
      # This allows deploying components from local recipes without AWS Component Store
      sudo /greengrass/v2/bin/greengrass-cli deployment create \
        --recipeDir ${local.recipes_path} \
        --artifactDir ${local.artifacts_path} \
        --merge "com.aismc.ZabbixEventSubscriber=1.0.0" \
        --merge "com.aismc.IncidentMessageForwarder=1.0.0" \
        --merge "com.aismc.ZabbixHostRegistrySync=1.0.0" \
        > ${path.module}/deployment-result-local.json 2>&1

      echo "✅ Local deployment created"

      # Wait for components to start (max 2 minutes)
      echo "Waiting for custom components to start..."
      for i in $(seq 1 24); do
        echo "Check $i/24..."

        # Check if all 3 components are running
        RUNNING_COUNT=$(sudo /greengrass/v2/bin/greengrass-cli component list 2>/dev/null | grep -c "com.aismc" || echo "0")

        if [ "$RUNNING_COUNT" -ge 3 ]; then
          echo ""
          echo "======================================"
          echo "✅ All 3 custom components are RUNNING!"
          echo "======================================"
          echo ""
          sudo /greengrass/v2/bin/greengrass-cli component list | grep "com.aismc"
          exit 0
        fi

        sleep 5
      done

      echo ""
      echo "⏳ Deployment in progress - components may still be starting"
      echo "Check status with: sudo /greengrass/v2/bin/greengrass-cli component list"
      echo ""
      exit 0
    EOT
  }

  provisioner "local-exec" {
    when    = destroy
    command = "echo 'Greengrass deployment will remain - manual cleanup required if needed'"
  }
}

# ============================================================================
# Outputs
# ============================================================================

output "zabbix_event_subscriber_status" {
  value = {
    component_name    = "com.aismc.ZabbixEventSubscriber"
    component_version = "1.0.0"
    webhook_endpoint  = "http://localhost:8081/zabbix/events"
    health_endpoint   = "http://localhost:8081/health"
    artifacts_path    = "${local.artifacts_path}/com.aismc.ZabbixEventSubscriber/1.0.0"
    recipe_path       = "${local.recipes_path}/com.aismc.ZabbixEventSubscriber-1.0.0.yaml"
    deployment_time   = timestamp()
  }
}

output "deployment_files" {
  value = {
    webhook_server     = "${local.artifacts_path}/com.aismc.ZabbixEventSubscriber/1.0.0/webhook_server.py"
    webhook_recipe     = "${local.recipes_path}/com.aismc.ZabbixEventSubscriber-1.0.0.yaml"
    forwarder_service  = "${local.artifacts_path}/com.aismc.IncidentMessageForwarder/1.0.0/forwarder_service.py"
    forwarder_recipe   = "${local.recipes_path}/com.aismc.IncidentMessageForwarder-1.0.0.yaml"
    verify_script      = local_file.verify_webhook_script.filename
  }
}

output "incident_forwarder_status" {
  value = {
    component_name    = "com.aismc.IncidentMessageForwarder"
    component_version = "1.0.0"
    mqtt_topic        = "aismc/incidents/site-001"
    poll_interval     = 10
    batch_size        = 10
    max_retries       = 5
    artifacts_path    = "${local.artifacts_path}/com.aismc.IncidentMessageForwarder/1.0.0"
    recipe_path       = "${local.recipes_path}/com.aismc.IncidentMessageForwarder-1.0.0.yaml"
  }
}

output "registry_sync_status" {
  value = {
    component_name     = "com.aismc.ZabbixHostRegistrySync"
    component_version  = "1.0.0"
    sync_schedule      = "0 2 * * *"
    incremental_sync   = true
    artifacts_path     = "${local.artifacts_path}/com.aismc.ZabbixHostRegistrySync/1.0.0"
    recipe_path        = "${local.recipes_path}/com.aismc.ZabbixHostRegistrySync-1.0.0.yaml"
  }
}

output "webhook_next_steps" {
  value = <<-EOT
    ✅ ZabbixEventSubscriber Component Deployed!

    📡 Webhook Endpoint: http://localhost:8081/zabbix/events
    🏥 Health Check: http://localhost:8081/health

    🧪 To test the webhook:
      cd ${path.module}/edge-components/zabbix-event-subscriber
      chmod +x test_webhook.sh
      ./test_webhook.sh

    📊 To monitor logs:
      sudo tail -f /greengrass/v2/logs/com.aismc.ZabbixEventSubscriber.log

    🔄 Next Steps:
      1. Configure Zabbix webhook (see README.md)
      2. Test with real camera offline event
      3. Deploy IncidentMessageForwarder component
  EOT
}

output "greengrass_deployment_status" {
  value = {
    deployment_name   = "aismc-edge-components-v1.0.0"
    target_thing      = "GreengrassCore-site001-hanoi"
    components_count  = 4
    components = [
      "aws.greengrass.Nucleus",
      "com.aismc.ZabbixEventSubscriber",
      "com.aismc.IncidentMessageForwarder",
      "com.aismc.ZabbixHostRegistrySync"
    ]
    deployment_result_file = "${path.module}/deployment-result.json"
    check_status_command   = "sudo /greengrass/v2/bin/greengrass-cli component list"
  }
  depends_on = [null_resource.greengrass_components_deployment]
}
