# Database Schema Migration v3.0: Unify cameras → devices
# Migration Strategy: cameras table → devices table with backward-compatible VIEW
# Date: 2026-01-02
# IaC Compliance: 100%

locals {
  migration_version = "v3.0-unified-devices"
  backup_timestamp  = formatdate("YYYY-MM-DD-hhmm", timestamp())
}

# Migration: Consolidate cameras into devices table
resource "null_resource" "database_migration_v3_cameras_to_devices" {
  triggers = {
    migration_version = local.migration_version
    # Re-run if migration script changes
    script_hash = md5(file("${path.module}/../scripts/migrate-cameras-to-devices.sh"))
  }

  provisioner "local-exec" {
    command = "bash ${path.module}/../scripts/migrate-cameras-to-devices.sh"
  }

  # Ensure database exists before migration
  depends_on = [
    null_resource.deploy_database_schema
  ]
}

# Health check after migration
resource "null_resource" "verify_migration_v3" {
  triggers = {
    migration_id = null_resource.database_migration_v3_cameras_to_devices.id
  }

  provisioner "local-exec" {
    command = <<-EOF
      echo "🔍 Verifying database migration v3.0..."

      # Check cameras VIEW exists
      CAMERAS_TYPE=$(sudo sqlite3 /var/greengrass/database/greengrass.db \
        "SELECT type FROM sqlite_master WHERE name='cameras'")

      if [ "$CAMERAS_TYPE" != "view" ]; then
        echo "❌ ERROR: cameras should be a VIEW, found: $CAMERAS_TYPE"
        exit 1
      fi

      # Verify camera count matches
      DEVICE_CAMERAS=$(sudo sqlite3 /var/greengrass/database/greengrass.db \
        "SELECT COUNT(*) FROM devices WHERE device_type='camera'")
      VIEW_CAMERAS=$(sudo sqlite3 /var/greengrass/database/greengrass.db \
        "SELECT COUNT(*) FROM cameras")

      if [ "$DEVICE_CAMERAS" != "$VIEW_CAMERAS" ]; then
        echo "❌ ERROR: Camera count mismatch - devices: $DEVICE_CAMERAS, view: $VIEW_CAMERAS"
        exit 1
      fi

      echo "✅ Migration verified: $VIEW_CAMERAS cameras in devices table"
      echo "✅ Backward compatibility: cameras VIEW working"

      # Check component health
      HEALTH=$(curl -s http://localhost:8081/health | grep -o '"status":"healthy"' || echo "")
      if [ -z "$HEALTH" ]; then
        echo "⚠️  WARNING: ZabbixEventSubscriber may need restart"
      else
        echo "✅ ZabbixEventSubscriber: healthy"
      fi
    EOF
  }

  depends_on = [
    null_resource.database_migration_v3_cameras_to_devices
  ]
}

# Output migration status
output "migration_v3_status" {
  value = {
    version           = local.migration_version
    migration_file    = "scripts/migrate-cameras-to-devices.sh"
    backup_location   = "/var/greengrass/database/greengrass.db.backup-*"
    cameras_table     = "Replaced with VIEW (backward compatible)"
    devices_table     = "Unified table for all device types"
    verification_id   = null_resource.verify_migration_v3.id
  }
}
