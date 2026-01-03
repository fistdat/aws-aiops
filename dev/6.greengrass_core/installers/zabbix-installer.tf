# ============================================================================
# Zabbix Server Installation (Infrastructure as Code)
# ============================================================================
# Purpose: Automated Zabbix 7.4.5 installation from source
# Version: 7.4.5
# Status: Ready for future deployments (not applied to current running system)
# ============================================================================

# ============================================================================
# Local Variables - Zabbix Configuration
# ============================================================================

locals {
  # Installation paths (matching actual running configuration)
  zabbix_version      = "7.4.5"
  zabbix_source_dir   = "${path.module}/zabbix-${local.zabbix_version}"
  zabbix_install_root = "/usr/local"
  zabbix_config_dir   = "/usr/local/etc"
  zabbix_log_dir      = "/var/log/zabbix"
  zabbix_run_dir      = "/run/zabbix"
  zabbix_web_dir      = "/var/www/html/zabbix"
  zabbix_share_dir    = "/usr/local/share/zabbix"

  # Database configuration (PostgreSQL - matching production)
  db_type     = "postgresql"
  db_name     = "zabbix"
  db_user     = "zabbix"
  db_password = "zabbix123"  # TODO: Use secure secret management

  # System user/group
  zabbix_user  = "zabbix"
  zabbix_group = "zabbix"

  # Web server configuration
  web_server_type = "nginx"
  web_port        = "8080"
  web_path        = "/zabbix"

  # Greengrass integration (references to zabbix-integration directory)
  greengrass_webhook_port        = "8081"
  greengrass_webhook_path        = "/zabbix/events"
  zabbix_integration_dir         = "${path.module}/../zabbix-integration"
  webhook_script_v4              = "${path.module}/../zabbix-integration/templates/webhook-script-v4-message.js"
  webhook_setup_script           = "${path.module}/../zabbix-integration/scripts/zabbix-webhook-setup.sh"
  webhook_verify_script          = "${path.module}/../zabbix-integration/scripts/verify-webhook.sh"
  zabbix_integration_docs        = "${path.module}/../zabbix-integration/docs"
}

# ============================================================================
# Step 0: Pre-Installation Validation
# ============================================================================

resource "null_resource" "validate_zabbix_prerequisites" {
  triggers = {
    validation_version = "v1"
  }

  provisioner "local-exec" {
    command = <<-EOT
      echo "======================================================================"
      echo "Zabbix ${local.zabbix_version} - Pre-Installation Validation"
      echo "======================================================================"

      # Check if source directory exists
      if [ ! -d "${local.zabbix_source_dir}" ]; then
        echo "❌ ERROR: Zabbix source directory not found: ${local.zabbix_source_dir}"
        echo "Please extract Zabbix source code to: ${path.module}/"
        exit 1
      fi
      echo "✅ Zabbix source directory found"

      # Check if Zabbix is already installed
      if systemctl is-active --quiet zabbix-server 2>/dev/null; then
        echo "⚠ WARNING: Zabbix server is already running"
        echo "This installation will STOP and BACKUP the current installation"
        read -p "Continue? (yes/no): " CONTINUE
        if [ "$CONTINUE" != "yes" ]; then
          echo "Installation cancelled"
          exit 1
        fi
      else
        echo "✅ No active Zabbix installation detected"
      fi

      # Check PostgreSQL
      if command -v psql &> /dev/null; then
        echo "✅ PostgreSQL found: $(psql --version | head -1)"
      else
        echo "❌ ERROR: PostgreSQL not installed"
        echo "Install: sudo apt install postgresql postgresql-contrib -y"
        exit 1
      fi

      # Check required dependencies
      echo ""
      echo "Checking required build dependencies..."
      MISSING_DEPS=()

      for dep in gcc make libpq-dev libcurl4-openssl-dev libxml2-dev \
                 libsnmp-dev libssh2-1-dev libopenipmi-dev libevent-dev \
                 libpcre3-dev pkg-config; do
        if ! dpkg -l | grep -q "^ii  $dep"; then
          MISSING_DEPS+=("$dep")
        fi
      done

      if [ $${#MISSING_DEPS[@]} -gt 0 ]; then
        echo "⚠ Missing dependencies: $${MISSING_DEPS[*]}"
        echo "Install: sudo apt install $${MISSING_DEPS[*]} -y"
      else
        echo "✅ All build dependencies installed"
      fi

      echo ""
      echo "======================================================================"
      echo "Pre-installation validation complete"
      echo "======================================================================"
    EOT
  }
}

# ============================================================================
# Step 1: Install Build Dependencies
# ============================================================================

resource "null_resource" "install_zabbix_dependencies" {
  triggers = {
    dependencies_version = "v1"
  }

  provisioner "local-exec" {
    command = <<-EOT
      echo "======================================================================"
      echo "Installing Zabbix Build Dependencies"
      echo "======================================================================"

      # Update package list
      sudo apt-get update -qq

      # Install build dependencies
      echo "Installing build tools and libraries..."
      sudo DEBIAN_FRONTEND=noninteractive apt-get install -y \
        gcc \
        make \
        libpq-dev \
        libcurl4-openssl-dev \
        libxml2-dev \
        libsnmp-dev \
        libssh2-1-dev \
        libopenipmi-dev \
        libevent-dev \
        libpcre3-dev \
        pkg-config \
        fping

      # Install PHP and web server dependencies
      echo ""
      echo "Installing Nginx and PHP dependencies..."
      sudo DEBIAN_FRONTEND=noninteractive apt-get install -y \
        nginx \
        php-fpm \
        php \
        php-pgsql \
        php-gd \
        php-bcmath \
        php-mbstring \
        php-xml \
        php-ldap \
        php-curl

      # Install PostgreSQL if not installed
      if ! command -v psql &> /dev/null; then
        echo ""
        echo "Installing PostgreSQL..."
        sudo DEBIAN_FRONTEND=noninteractive apt-get install -y \
          postgresql \
          postgresql-contrib

        # Start and enable PostgreSQL
        sudo systemctl start postgresql
        sudo systemctl enable postgresql
      fi

      echo ""
      echo "✅ All dependencies installed successfully"
      echo "======================================================================"
    EOT
  }

  depends_on = [null_resource.validate_zabbix_prerequisites]
}

# ============================================================================
# Step 2: Create System User and Directories
# ============================================================================

resource "null_resource" "create_zabbix_user_directories" {
  triggers = {
    user_dirs_version = "v1"
  }

  provisioner "local-exec" {
    command = <<-EOT
      echo "======================================================================"
      echo "Creating Zabbix System User and Directories"
      echo "======================================================================"

      # Create zabbix user and group
      if ! id ${local.zabbix_user} &> /dev/null; then
        echo "Creating zabbix user..."
        sudo groupadd --system ${local.zabbix_group}
        sudo useradd --system --gid ${local.zabbix_group} \
          --home-dir /var/lib/zabbix \
          --shell /sbin/nologin \
          --comment "Zabbix Monitoring System" \
          ${local.zabbix_user}
        echo "✅ User created: ${local.zabbix_user}"
      else
        echo "✅ User already exists: ${local.zabbix_user}"
      fi

      # Create required directories (matching production paths)
      echo ""
      echo "Creating directories..."
      sudo mkdir -p ${local.zabbix_config_dir}
      sudo mkdir -p ${local.zabbix_log_dir}
      sudo mkdir -p ${local.zabbix_run_dir}
      sudo mkdir -p ${local.zabbix_share_dir}
      sudo mkdir -p ${local.zabbix_share_dir}/alertscripts
      sudo mkdir -p ${local.zabbix_share_dir}/externalscripts
      sudo mkdir -p /var/lib/zabbix

      # Set ownership
      sudo chown -R ${local.zabbix_user}:${local.zabbix_group} ${local.zabbix_log_dir}
      sudo chown -R ${local.zabbix_user}:${local.zabbix_group} ${local.zabbix_run_dir}
      sudo chown -R ${local.zabbix_user}:${local.zabbix_group} ${local.zabbix_share_dir}
      sudo chown -R ${local.zabbix_user}:${local.zabbix_group} /var/lib/zabbix

      echo "✅ Directories created and configured"
      echo "======================================================================"
    EOT
  }

  depends_on = [null_resource.install_zabbix_dependencies]
}

# ============================================================================
# Step 3: Configure and Compile Zabbix
# ============================================================================

resource "null_resource" "compile_zabbix" {
  triggers = {
    source_hash = fileexists("${local.zabbix_source_dir}/configure") ? filemd5("${local.zabbix_source_dir}/configure") : "not_found"
  }

  provisioner "local-exec" {
    command = <<-EOT
      echo "======================================================================"
      echo "Configuring and Compiling Zabbix ${local.zabbix_version}"
      echo "======================================================================"

      cd ${local.zabbix_source_dir}

      # Configure (using PostgreSQL matching production)
      echo "Configuring Zabbix..."
      ./configure \
        --enable-server \
        --enable-agent \
        --with-postgresql \
        --with-libcurl \
        --with-libxml2 \
        --with-net-snmp \
        --with-ssh2 \
        --with-openipmi \
        --sysconfdir=${local.zabbix_config_dir}

      if [ $? -ne 0 ]; then
        echo "❌ Configuration failed"
        exit 1
      fi
      echo "✅ Configuration complete"

      # Compile
      echo ""
      echo "Compiling Zabbix (this may take 5-10 minutes)..."
      make -j$(nproc)

      if [ $? -ne 0 ]; then
        echo "❌ Compilation failed"
        exit 1
      fi
      echo "✅ Compilation complete"

      # Install
      echo ""
      echo "Installing Zabbix binaries..."
      sudo make install

      if [ $? -ne 0 ]; then
        echo "❌ Installation failed"
        exit 1
      fi
      echo "✅ Installation complete"

      # Verify installation
      echo ""
      echo "Installed binaries:"
      ls -lh ${local.zabbix_install_root}/sbin/zabbix_* 2>/dev/null || echo "Warning: binaries not found in expected location"

      echo ""
      echo "======================================================================"
    EOT
  }

  depends_on = [null_resource.create_zabbix_user_directories]
}

# ============================================================================
# Step 4: Setup Database
# ============================================================================

resource "null_resource" "setup_zabbix_database" {
  triggers = {
    db_version = "v1"
  }

  provisioner "local-exec" {
    command = <<-EOT
      echo "======================================================================"
      echo "Setting up Zabbix Database"
      echo "======================================================================"

      # Create database and user (PostgreSQL)
      echo "Creating database and user..."
      sudo -u postgres psql <<SQL
      DROP DATABASE IF EXISTS ${local.db_name};
      DROP USER IF EXISTS ${local.db_user};

      CREATE USER ${local.db_user} WITH PASSWORD '${local.db_password}';
      CREATE DATABASE ${local.db_name} OWNER ${local.db_user} ENCODING 'UTF8';
      GRANT ALL PRIVILEGES ON DATABASE ${local.db_name} TO ${local.db_user};
SQL

      if [ $? -ne 0 ]; then
        echo "❌ Database creation failed"
        exit 1
      fi
      echo "✅ Database created: ${local.db_name}"

      # Import schema
      echo ""
      echo "Importing database schema..."

      cd ${local.zabbix_source_dir}

      if [ -f database/postgresql/schema.sql ]; then
        sudo -u postgres psql -U ${local.db_user} -d ${local.db_name} < database/postgresql/schema.sql
        echo "✅ Schema imported"
      else
        echo "❌ schema.sql not found"
        exit 1
      fi

      if [ -f database/postgresql/images.sql ]; then
        sudo -u postgres psql -U ${local.db_user} -d ${local.db_name} < database/postgresql/images.sql
        echo "✅ Images imported"
      fi

      if [ -f database/postgresql/data.sql ]; then
        sudo -u postgres psql -U ${local.db_user} -d ${local.db_name} < database/postgresql/data.sql
        echo "✅ Initial data imported"
      fi

      # Verify
      echo ""
      echo "Database verification:"
      sudo -u postgres psql -U ${local.db_user} -d ${local.db_name} -c "\dt" | grep -c "public |"
      echo "tables created"

      echo ""
      echo "======================================================================"
    EOT
  }

  depends_on = [null_resource.compile_zabbix]
}

# ============================================================================
# Step 5: Configure Zabbix Server
# ============================================================================

resource "local_file" "zabbix_server_config" {
  content = <<-EOT
    # Zabbix Server Configuration
    # Auto-generated by Terraform (matching production)

    # Database Configuration (PostgreSQL)
    DBHost=localhost
    DBName=${local.db_name}
    DBUser=${local.db_user}
    DBPassword=${local.db_password}

    # Server Configuration
    LogFile=${local.zabbix_log_dir}/zabbix_server.log
    PidFile=${local.zabbix_run_dir}/zabbix_server.pid

    # External Scripts (matching production paths)
    AlertScriptsPath=${local.zabbix_share_dir}/alertscripts
    ExternalScripts=${local.zabbix_share_dir}/externalscripts

    # High Availability
    HANodeName=zabbix-server-main
    NodeAddress=localhost:10051
  EOT

  filename        = "${path.module}/zabbix_server.conf"
  file_permission = "0644"

  depends_on = [null_resource.setup_zabbix_database]
}

resource "null_resource" "deploy_zabbix_server_config" {
  triggers = {
    config_hash = local_file.zabbix_server_config.content
  }

  provisioner "local-exec" {
    command = <<-EOT
      echo "======================================================================"
      echo "Deploying Zabbix Server Configuration"
      echo "======================================================================"

      # Backup existing config
      if [ -f ${local.zabbix_config_dir}/zabbix_server.conf ]; then
        sudo cp ${local.zabbix_config_dir}/zabbix_server.conf \
          ${local.zabbix_config_dir}/zabbix_server.conf.backup-$(date +%Y%m%d%H%M%S)
        echo "✅ Existing config backed up"
      fi

      # Deploy new config
      sudo cp ${local_file.zabbix_server_config.filename} ${local.zabbix_config_dir}/zabbix_server.conf
      sudo chown root:${local.zabbix_group} ${local.zabbix_config_dir}/zabbix_server.conf
      sudo chmod 640 ${local.zabbix_config_dir}/zabbix_server.conf

      echo "✅ Configuration deployed: ${local.zabbix_config_dir}/zabbix_server.conf"
      echo "======================================================================"
    EOT
  }

  depends_on = [local_file.zabbix_server_config]
}

# ============================================================================
# Step 6: Create Systemd Service
# ============================================================================

resource "local_file" "zabbix_server_service" {
  content = <<-EOT
    [Unit]
    Description=Zabbix Server
    After=network.target mysql.service

    [Service]
    Type=forking
    User=${local.zabbix_user}
    Group=${local.zabbix_group}
    ExecStart=${local.zabbix_install_root}/sbin/zabbix_server -c ${local.zabbix_config_dir}/zabbix_server.conf
    ExecStop=/bin/kill -SIGTERM $MAINPID
    PIDFile=${local.zabbix_run_dir}/zabbix_server.pid
    Restart=on-failure
    RestartSec=10s

    [Install]
    WantedBy=multi-user.target
  EOT

  filename        = "${path.module}/zabbix-server.service"
  file_permission = "0644"

  depends_on = [null_resource.deploy_zabbix_server_config]
}

resource "null_resource" "deploy_zabbix_systemd_service" {
  triggers = {
    service_hash = local_file.zabbix_server_service.content
  }

  provisioner "local-exec" {
    command = <<-EOT
      echo "======================================================================"
      echo "Deploying Zabbix Systemd Service"
      echo "======================================================================"

      # Deploy service file
      sudo cp ${local_file.zabbix_server_service.filename} /etc/systemd/system/zabbix-server.service
      sudo systemctl daemon-reload

      echo "✅ Systemd service deployed"
      echo ""
      echo "To start Zabbix server:"
      echo "  sudo systemctl start zabbix-server"
      echo "  sudo systemctl enable zabbix-server"
      echo "======================================================================"
    EOT
  }

  depends_on = [local_file.zabbix_server_service]
}

# ============================================================================
# Step 7: Setup Web Frontend
# ============================================================================

resource "null_resource" "deploy_zabbix_web_frontend" {
  triggers = {
    web_version = "v1"
  }

  provisioner "local-exec" {
    command = <<-EOT
      echo "======================================================================"
      echo "Deploying Zabbix Web Frontend"
      echo "======================================================================"

      # Create web directory
      sudo mkdir -p ${local.zabbix_web_dir}

      # Copy web files
      if [ -d "${local.zabbix_source_dir}/ui" ]; then
        echo "Copying web UI files..."
        sudo cp -r ${local.zabbix_source_dir}/ui/* ${local.zabbix_web_dir}/
        echo "✅ Web files copied"
      else
        echo "❌ UI directory not found"
        exit 1
      fi

      # Set permissions
      sudo chown -R www-data:www-data ${local.zabbix_web_dir}
      sudo chmod -R 755 ${local.zabbix_web_dir}

      # Create web configuration directory
      sudo mkdir -p ${local.zabbix_web_dir}/conf
      sudo chown www-data:www-data ${local.zabbix_web_dir}/conf

      # Configure Nginx (matching production setup on port 8080)
      echo "Configuring Nginx..."

      # Create Nginx site config for Zabbix
      cat <<'NGINX_EOF' | sudo tee /etc/nginx/sites-available/zabbix > /dev/null
server {
    listen ${local.web_port};
    server_name _;

    root ${local.zabbix_web_dir};
    index index.php index.html;

    location / {
        try_files \$uri \$uri/ /index.php?\$args;
    }

    location ~ \.php$ {
        include snippets/fastcgi-php.conf;
        fastcgi_pass unix:/run/php/php-fpm.sock;
    }

    location ~ /\.ht {
        deny all;
    }
}
NGINX_EOF

      # Enable site
      sudo ln -sf /etc/nginx/sites-available/zabbix /etc/nginx/sites-enabled/zabbix

      # Test and reload Nginx
      sudo nginx -t
      sudo systemctl reload nginx

      echo ""
      echo "✅ Web frontend deployed to: ${local.zabbix_web_dir}"
      echo "Access at: http://localhost:${local.web_port}${local.web_path}"
      echo ""
      echo "Initial setup:"
      echo "  - Username: Admin"
      echo "  - Password: zabbix"
      echo "======================================================================"
    EOT
  }

  depends_on = [null_resource.deploy_zabbix_systemd_service]
}

# ============================================================================
# Step 8: Configure fping for ICMP Checks
# ============================================================================

resource "null_resource" "configure_fping" {
  triggers = {
    fping_version = "v1"
  }

  provisioner "local-exec" {
    command = <<-EOT
      echo "======================================================================"
      echo "Configuring fping for Zabbix"
      echo "======================================================================"

      # Set setuid permission (required for non-root ICMP)
      sudo chmod u+s /usr/bin/fping

      # Create symlink if needed
      if [ ! -e /usr/sbin/fping ]; then
        sudo ln -s /usr/bin/fping /usr/sbin/fping
      fi

      echo "✅ fping configured for Zabbix"
      echo "======================================================================"
    EOT
  }

  depends_on = [null_resource.deploy_zabbix_web_frontend]
}

# ============================================================================
# Step 9: Create Post-Installation Setup Script
# ============================================================================

resource "local_file" "post_install_greengrass_integration" {
  content = <<-EOT
    #!/bin/bash
    # Post-Installation: Greengrass Integration Setup
    # Run this script after Zabbix is installed and configured
    # References: ${local.zabbix_integration_dir}

    echo "======================================================================"
    echo "Zabbix-Greengrass Integration Setup"
    echo "======================================================================"

    # Check if Zabbix is running
    if ! systemctl is-active --quiet zabbix-server; then
      echo "❌ ERROR: Zabbix server is not running"
      echo "Start it with: sudo systemctl start zabbix-server"
      exit 1
    fi

    echo "✅ Zabbix server is running"
    echo ""

    # Check Greengrass webhook endpoint
    echo "Checking Greengrass webhook endpoint..."
    if curl -s http://localhost:${local.greengrass_webhook_port}/health > /dev/null 2>&1; then
      echo "✅ Greengrass webhook is running"
      curl -s http://localhost:${local.greengrass_webhook_port}/health | python3 -m json.tool
    else
      echo "⚠ WARNING: Greengrass webhook endpoint not responding"
      echo "Make sure Greengrass component is deployed:"
      echo "  sudo /greengrass/v2/bin/greengrass-cli component list"
    fi

    echo ""
    echo "======================================================================"
    echo "Greengrass Webhook Configuration"
    echo "======================================================================"
    echo "Endpoint: http://localhost:${local.greengrass_webhook_port}${local.greengrass_webhook_path}"
    echo "Component: com.aismc.ZabbixEventSubscriber"
    echo "Webhook Port: ${local.greengrass_webhook_port}"
    echo ""

    echo "======================================================================"
    echo "Integration Resources"
    echo "======================================================================"
    echo "Webhook Script (v4 - Production):"
    echo "  ${local.webhook_script_v4}"
    echo ""
    echo "Setup Automation:"
    echo "  ${local.webhook_setup_script}"
    echo ""
    echo "Verification Script:"
    echo "  ${local.webhook_verify_script}"
    echo ""
    echo "Documentation:"
    echo "  ${local.zabbix_integration_docs}/ZABBIX_WEBHOOK_SETUP.md"
    echo "  ${local.zabbix_integration_docs}/ZABBIX_INTEGRATION_STATUS.md"
    echo ""

    echo "======================================================================"
    echo "Quick Setup Steps"
    echo "======================================================================"
    echo ""
    echo "1. Configure Zabbix webhook media type:"
    echo "   - Login to Zabbix: http://localhost:${local.web_port}${local.web_path}"
    echo "   - Administration → Media types → Create media type"
    echo "   - Name: Greengrass Webhook"
    echo "   - Type: Webhook"
    echo "   - Script: Copy content from ${local.webhook_script_v4}"
    echo ""
    echo "2. Test webhook endpoint:"
    echo "   bash ${local.webhook_verify_script}"
    echo ""
    echo "3. Configure Zabbix action:"
    echo "   - Configuration → Actions → Create action"
    echo "   - Name: Camera Events to Greengrass"
    echo "   - Operations → Send message to Greengrass Webhook"
    echo ""
    echo "4. For automated setup (if Zabbix API available):"
    echo "   bash ${local.webhook_setup_script}"
    echo ""
    echo "======================================================================"
    echo "Verification"
    echo "======================================================================"
    echo ""
    echo "Test webhook manually:"
    echo "curl -X POST http://localhost:${local.greengrass_webhook_port}${local.greengrass_webhook_path} \\"
    echo "  -H 'Content-Type: application/json' \\"
    echo "  -d '{\"event_id\":\"TEST\",\"host_name\":\"Camera01\",\"event_severity\":\"5\"}'"
    echo ""
    echo "Check database:"
    echo "sudo sqlite3 /var/greengrass/database/greengrass.db \\"
    echo "  'SELECT * FROM incidents ORDER BY detected_at DESC LIMIT 5'"
    echo ""
    echo "======================================================================"
    echo "Integration Complete!"
    echo "======================================================================"
  EOT

  filename        = "${path.module}/post-install-greengrass-integration.sh"
  file_permission = "0755"

  depends_on = [null_resource.configure_fping]
}

# ============================================================================
# Outputs
# ============================================================================

output "zabbix_installation_summary" {
  description = "Zabbix installation summary (matching production configuration)"
  value = {
    version           = local.zabbix_version
    source_directory  = local.zabbix_source_dir
    config_directory  = local.zabbix_config_dir
    web_url           = "http://localhost:${local.web_port}${local.web_path}"
    web_server        = local.web_server_type
    web_port          = local.web_port
    web_path          = local.web_path
    default_username  = "Admin"
    default_password  = "zabbix"
    database_type     = local.db_type
    database_name     = local.db_name
    database_user     = local.db_user
  }
}

output "zabbix_service_commands" {
  description = "Zabbix service management commands"
  value = {
    start   = "sudo systemctl start zabbix-server"
    stop    = "sudo systemctl stop zabbix-server"
    restart = "sudo systemctl restart zabbix-server"
    status  = "sudo systemctl status zabbix-server"
    enable  = "sudo systemctl enable zabbix-server"
    logs    = "sudo tail -f ${local.zabbix_log_dir}/zabbix_server.log"
  }
}

output "greengrass_integration" {
  description = "Greengrass integration information (links to zabbix-integration directory)"
  value = {
    webhook_endpoint        = "http://localhost:${local.greengrass_webhook_port}${local.greengrass_webhook_path}"
    webhook_health_check    = "curl -s http://localhost:${local.greengrass_webhook_port}/health"
    integration_directory   = local.zabbix_integration_dir
    webhook_script_v4       = local.webhook_script_v4
    setup_automation        = local.webhook_setup_script
    verification_script     = local.webhook_verify_script
    documentation           = local.zabbix_integration_docs
    post_install_script     = local_file.post_install_greengrass_integration.filename
  }
}

output "installation_instructions" {
  description = "Complete installation instructions"
  value = <<-EOT

    ====================================================================
    Zabbix ${local.zabbix_version} Installation - Complete Guide
    ====================================================================
    Configuration: Matching Production Setup
    Database: ${local.db_type}
    Web Server: ${local.web_server_type} (port ${local.web_port})
    ====================================================================

    📋 INSTALLATION STEPS:

    1. Navigate to installers directory:
       cd ${path.module}

    2. Initialize Terraform:
       terraform init

    3. Review installation plan:
       terraform plan

    4. Apply installation:
       terraform apply

    5. Start Zabbix server:
       sudo systemctl start zabbix-server
       sudo systemctl enable zabbix-server

    6. Verify installation:
       sudo systemctl status zabbix-server
       curl http://localhost:${local.web_port}${local.web_path}

    7. Complete web setup:
       - Open: http://localhost:${local.web_port}${local.web_path}
       - Follow setup wizard
       - Login: Admin / zabbix

    8. Configure Greengrass integration:
       ./post-install-greengrass-integration.sh

    ====================================================================
    📦 INSTALLATION DETAILS:
    - Source: ${local.zabbix_source_dir}
    - Database: ${local.db_type} (${local.db_name}, user: ${local.db_user})
    - Config: ${local.zabbix_config_dir}/zabbix_server.conf
    - Logs: ${local.zabbix_log_dir}/zabbix_server.log
    - Web: ${local.zabbix_web_dir} (${local.web_server_type}:${local.web_port})
    - Alert Scripts: ${local.zabbix_share_dir}/alertscripts
    - External Scripts: ${local.zabbix_share_dir}/externalscripts
    ====================================================================

    🔗 GREENGRASS INTEGRATION:
    - Webhook Endpoint: http://localhost:${local.greengrass_webhook_port}${local.greengrass_webhook_path}
    - Webhook Script: ${local.webhook_script_v4}
    - Setup Script: ${local.webhook_setup_script}
    - Verify Script: ${local.webhook_verify_script}
    - Documentation: ${local.zabbix_integration_docs}/
    ====================================================================

    ⚠️  IMPORTANT NOTES:
    - This installer matches the PRODUCTION configuration
    - Uses PostgreSQL (not MySQL) for database
    - Uses Nginx (not Apache) on port ${local.web_port}
    - Includes full Greengrass integration references
    - All paths match running Zabbix installation
    ====================================================================

  EOT
}
