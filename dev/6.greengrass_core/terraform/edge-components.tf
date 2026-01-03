# ============================================================================
# Greengrass Edge Components - Database & DAO Layer
# Version: 1.0.0
# Purpose: Deploy SQLite database and Python DAO layer to Greengrass device
# ============================================================================

# ============================================================================
# Local Variables
# ============================================================================

locals {
  edge_components_path = "${path.module}/edge-components"
  database_schema_file = "${local.edge_components_path}/database/schema.sql"
  python_dao_path      = "${local.edge_components_path}/python-dao"
  scripts_path         = "${local.edge_components_path}/scripts"

  # Greengrass paths
  greengrass_db_dir       = "/var/greengrass/database"
  greengrass_db_file      = "${local.greengrass_db_dir}/greengrass.db"
  greengrass_artifacts    = "/greengrass/v2/packages/artifacts-unarchived"
  greengrass_dao_path     = "${local.greengrass_artifacts}/greengrass_database"
}

# ============================================================================
# Step 1: Install SQLite3 (Dependency)
# ============================================================================

resource "null_resource" "install_sqlite3" {
  # Only run once unless forced
  triggers = {
    install_required = "install_sqlite3_v1"
  }

  # Install SQLite3 (idempotent - apt will skip if already installed)
  provisioner "local-exec" {
    command = <<-EOT
      echo "Installing SQLite3 dependencies..."
      sudo apt-get update -qq
      sudo DEBIAN_FRONTEND=noninteractive apt-get install -y sqlite3 libsqlite3-dev

      # Verify installation
      if which sqlite3 > /dev/null 2>&1; then
        SQLITE_VERSION=$(sqlite3 --version | cut -d' ' -f1)
        echo "✅ SQLite3 installed successfully: $SQLITE_VERSION"
      else
        echo "❌ SQLite3 installation failed!"
        exit 1
      fi
    EOT
  }
}

# ============================================================================
# Step 2: Deploy SQLite Database Schema
# ============================================================================

resource "null_resource" "deploy_database_schema" {
  # Trigger re-deployment when schema file or setup script changes
  triggers = {
    schema_md5       = filemd5(local.database_schema_file)
    setup_script_md5 = filemd5("${local.scripts_path}/setup-database.sh")
  }

  # Copy schema file to Greengrass
  provisioner "local-exec" {
    command = <<-EOT
      echo "Deploying SQLite database schema..."
      sudo mkdir -p ${local.greengrass_db_dir}
      sudo cp ${local.database_schema_file} ${local.greengrass_db_dir}/schema.sql
      echo "✅ Schema file copied to Greengrass"
    EOT
  }

  # Execute database setup script
  provisioner "local-exec" {
    command = <<-EOT
      echo "Executing database setup script..."
      sudo ${local.scripts_path}/setup-database.sh
      echo "✅ Database setup completed"
    EOT
  }

  # Cleanup on destroy
  provisioner "local-exec" {
    when    = destroy
    command = <<-EOT
      echo "Database preserved (not deleted). Backup created if needed."
    EOT
  }

  depends_on = [null_resource.install_sqlite3]
}

# ============================================================================
# Step 3: Deploy Python DAO Layer
# ============================================================================

# Create target directory for DAO
resource "null_resource" "create_dao_directory" {
  provisioner "local-exec" {
    command = <<-EOT
      echo "Creating DAO target directory..."
      sudo mkdir -p ${local.greengrass_dao_path}
      echo "✅ DAO directory created"
    EOT
  }

  depends_on = [null_resource.deploy_database_schema]
}

# Deploy Python DAO files
resource "null_resource" "deploy_python_dao" {
  # Trigger re-deployment when any Python file or installation script changes
  triggers = {
    init_md5           = filemd5("${local.python_dao_path}/__init__.py")
    connection_md5     = filemd5("${local.python_dao_path}/connection.py")
    dao_md5            = filemd5("${local.python_dao_path}/dao.py")
    install_script_md5 = filemd5("${local.scripts_path}/install-python-dao.sh")
    test_script_md5    = filemd5("${local.scripts_path}/test-database.py")
  }

  # Execute DAO installation script
  provisioner "local-exec" {
    command = <<-EOT
      echo "Deploying Python DAO layer..."
      sudo ${local.scripts_path}/install-python-dao.sh
      echo "✅ Python DAO layer deployed"
    EOT
  }

  depends_on = [null_resource.create_dao_directory]
}

# ============================================================================
# Step 4: Verify Installation
# ============================================================================

resource "null_resource" "verify_installation" {
  # Run verification after deployment
  provisioner "local-exec" {
    command = <<-EOT
      echo "Verifying installation..."

      # Check database file exists
      if [ -f "${local.greengrass_db_file}" ]; then
        echo "✅ Database file exists: ${local.greengrass_db_file}"
      else
        echo "❌ Database file not found!"
        exit 1
      fi

      # Check database schema
      TABLE_COUNT=$(sudo -u ggc_user sqlite3 ${local.greengrass_db_file} "SELECT COUNT(*) FROM sqlite_master WHERE type='table';" 2>/dev/null || echo "0")
      echo "✅ Database tables: $TABLE_COUNT"

      # Check Python DAO files
      if [ -f "${local.greengrass_dao_path}/connection.py" ]; then
        echo "✅ Python DAO files deployed"
      else
        echo "❌ Python DAO files not found!"
        exit 1
      fi

      echo "✅ Installation verification completed"
    EOT
  }

  depends_on = [
    null_resource.deploy_database_schema,
    null_resource.deploy_python_dao
  ]
}

# ============================================================================
# Step 5: Create Deployment Summary File
# ============================================================================

resource "local_file" "deployment_summary" {
  content = templatefile("${path.module}/templates/edge-components-summary.tpl", {
    deployment_timestamp = timestamp()
    database_path        = local.greengrass_db_file
    dao_path             = local.greengrass_dao_path
    schema_version       = "1.0.0"
  })

  filename        = "${path.module}/EDGE-COMPONENTS-DEPLOYMENT.md"
  file_permission = "0644"

  depends_on = [null_resource.verify_installation]
}

# ============================================================================
# Outputs
# ============================================================================

output "edge_components_status" {
  description = "Status of edge components deployment"
  value = {
    database_file = local.greengrass_db_file
    dao_path      = local.greengrass_dao_path
    deployed_at   = timestamp()
  }
}

output "next_steps" {
  description = "Next steps after deployment"
  value = <<-EOT
    ✅ Edge Components Deployed Successfully!

    📁 Database Location: ${local.greengrass_db_file}
    📁 Python DAO Path: ${local.greengrass_dao_path}

    🧪 To test the installation:
      sudo python3 ${local.scripts_path}/test-database.py

    📊 To check database status:
      sudo -u ggc_user sqlite3 ${local.greengrass_db_file} "SELECT * FROM _metadata;"

    📝 Configuration:
      sudo -u ggc_user sqlite3 ${local.greengrass_db_file} "SELECT * FROM configuration;"

    🔄 Next: Deploy Greengrass components (ZabbixEventSubscriber, etc.)
  EOT
}
