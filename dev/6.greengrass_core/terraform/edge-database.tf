# ============================================================================
# Edge Database DAO Layer Deployment
# ============================================================================
# Purpose: Deploy Database DAO Layer to Greengrass Core via Terraform
# Version: 1.0.0
# Managed By: Terraform
# ============================================================================

locals {
  dao_base_path        = "/greengrass/v2/components/common"
  dao_database_path    = "${local.dao_base_path}/database"
  dao_utils_path       = "${local.dao_base_path}/utils"
  edge_database_source = "${path.module}/edge-database/src"
  test_source          = "${path.module}/edge-database/tests"
  scripts_source       = "${path.module}/edge-database/scripts"
}

# ============================================================================
# Create Directory Structure
# ============================================================================

resource "null_resource" "create_dao_directories" {
  triggers = {
    always_run = timestamp()
  }

  provisioner "local-exec" {
    command = <<-EOT
      sudo mkdir -p ${local.dao_database_path}
      sudo mkdir -p ${local.dao_utils_path}
      sudo chown -R ggc_user:ggc_group ${local.dao_base_path}
      sudo chmod -R 755 ${local.dao_base_path}
      echo "✅ DAO directories created"
    EOT
  }
}

# ============================================================================
# Deploy Database Package Files
# ============================================================================

resource "null_resource" "deploy_database_init" {
  triggers = {
    file_md5 = filemd5("${local.edge_database_source}/database/__init__.py")
  }

  depends_on = [null_resource.create_dao_directories]

  provisioner "local-exec" {
    command = <<-EOT
      sudo cp ${local.edge_database_source}/database/__init__.py ${local.dao_database_path}/__init__.py
      sudo chown ggc_user:ggc_group ${local.dao_database_path}/__init__.py
      sudo chmod 644 ${local.dao_database_path}/__init__.py
      echo "✅ Deployed database/__init__.py"
    EOT
  }
}

resource "null_resource" "deploy_database_connection" {
  triggers = {
    file_md5 = filemd5("${local.edge_database_source}/database/connection.py")
  }

  depends_on = [null_resource.create_dao_directories]

  provisioner "local-exec" {
    command = <<-EOT
      sudo cp ${local.edge_database_source}/database/connection.py ${local.dao_database_path}/connection.py
      sudo chown ggc_user:ggc_group ${local.dao_database_path}/connection.py
      sudo chmod 644 ${local.dao_database_path}/connection.py
      echo "✅ Deployed database/connection.py"
    EOT
  }
}

resource "null_resource" "deploy_database_dao" {
  triggers = {
    file_md5 = filemd5("${local.edge_database_source}/database/dao.py")
  }

  depends_on = [null_resource.create_dao_directories]

  provisioner "local-exec" {
    command = <<-EOT
      sudo cp ${local.edge_database_source}/database/dao.py ${local.dao_database_path}/dao.py
      sudo chown ggc_user:ggc_group ${local.dao_database_path}/dao.py
      sudo chmod 644 ${local.dao_database_path}/dao.py
      echo "✅ Deployed database/dao.py"
    EOT
  }
}

resource "null_resource" "deploy_database_device_dao" {
  triggers = {
    file_md5 = filemd5("${local.edge_database_source}/database/device_dao.py")
  }

  depends_on = [null_resource.create_dao_directories]

  provisioner "local-exec" {
    command = <<-EOT
      sudo cp ${local.edge_database_source}/database/device_dao.py ${local.dao_database_path}/device_dao.py
      sudo chown ggc_user:ggc_group ${local.dao_database_path}/device_dao.py
      sudo chmod 644 ${local.dao_database_path}/device_dao.py
      echo "✅ Deployed database/device_dao.py"
    EOT
  }
}

# ============================================================================
# Deploy Utils Package Files
# ============================================================================

resource "null_resource" "deploy_utils_init" {
  triggers = {
    file_md5 = filemd5("${local.edge_database_source}/utils/__init__.py")
  }

  depends_on = [null_resource.create_dao_directories]

  provisioner "local-exec" {
    command = <<-EOT
      sudo cp ${local.edge_database_source}/utils/__init__.py ${local.dao_utils_path}/__init__.py
      sudo chown ggc_user:ggc_group ${local.dao_utils_path}/__init__.py
      sudo chmod 644 ${local.dao_utils_path}/__init__.py
      echo "✅ Deployed utils/__init__.py"
    EOT
  }
}

resource "null_resource" "deploy_utils_ngsi_ld" {
  triggers = {
    file_md5 = filemd5("${local.edge_database_source}/utils/ngsi_ld.py")
  }

  depends_on = [null_resource.create_dao_directories]

  provisioner "local-exec" {
    command = <<-EOT
      sudo cp ${local.edge_database_source}/utils/ngsi_ld.py ${local.dao_utils_path}/ngsi_ld.py
      sudo chown ggc_user:ggc_group ${local.dao_utils_path}/ngsi_ld.py
      sudo chmod 644 ${local.dao_utils_path}/ngsi_ld.py
      echo "✅ Deployed utils/ngsi_ld.py"
    EOT
  }
}

# ============================================================================
# Apply Database Schema Updates
# ============================================================================

resource "null_resource" "apply_schema_update_v2" {
  triggers = {
    schema_md5 = filemd5("${path.module}/edge-database/schema/schema_update_v2.sql")
  }

  depends_on = [
    null_resource.deploy_database_device_dao,
    null_resource.deploy_utils_ngsi_ld
  ]

  provisioner "local-exec" {
    command = <<-EOT
      echo "Applying schema update v2..."
      sudo sqlite3 /var/greengrass/database/greengrass.db < ${path.module}/edge-database/schema/schema_update_v2.sql
      echo "✅ Schema update v2 applied successfully"
    EOT
  }
}

# ============================================================================
# Deploy Verification Script
# ============================================================================

resource "null_resource" "deploy_verification_script" {
  triggers = {
    file_md5 = filemd5("${local.scripts_source}/verify_dao.sh")
  }

  depends_on = [
    null_resource.deploy_database_init,
    null_resource.deploy_database_connection,
    null_resource.deploy_database_dao,
    null_resource.deploy_database_device_dao,
    null_resource.deploy_utils_init,
    null_resource.deploy_utils_ngsi_ld,
    null_resource.apply_schema_update_v2
  ]

  provisioner "local-exec" {
    command = <<-EOT
      sudo cp ${local.scripts_source}/verify_dao.sh /greengrass/v2/scripts/verify_dao.sh
      sudo chmod 755 /greengrass/v2/scripts/verify_dao.sh
      echo "✅ Deployed verification script"
    EOT
  }
}

# ============================================================================
# Run Verification
# ============================================================================

resource "null_resource" "verify_dao_deployment" {
  triggers = {
    deployment_complete = null_resource.deploy_verification_script.id
  }

  depends_on = [null_resource.deploy_verification_script]

  provisioner "local-exec" {
    command = "/greengrass/v2/scripts/verify_dao.sh"
  }
}

# ============================================================================
# Outputs
# ============================================================================

output "dao_layer_deployment_status" {
  value = {
    base_path        = local.dao_base_path
    database_path    = local.dao_database_path
    utils_path       = local.dao_utils_path
    verification_script = "/greengrass/v2/scripts/verify_dao.sh"
    deployment_time  = timestamp()
  }
}

output "deployed_files" {
  value = {
    database_package = [
      "${local.dao_database_path}/__init__.py",
      "${local.dao_database_path}/connection.py",
      "${local.dao_database_path}/dao.py",
      "${local.dao_database_path}/device_dao.py"
    ]
    utils_package = [
      "${local.dao_utils_path}/__init__.py",
      "${local.dao_utils_path}/ngsi_ld.py"
    ]
    schema_updates = [
      "schema_update_v2.sql (applied)"
    ]
  }
}
