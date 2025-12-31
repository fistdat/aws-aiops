# ============================================================================
# Greengrass Installation Management (Infrastructure as Code)
# ============================================================================
# This module manages Greengrass Core installation and re-provisioning
# ============================================================================

# Create installation script
resource "local_file" "greengrass_install_script" {
  content = templatefile("${path.module}/templates/install-greengrass.sh.tpl", {
    thing_name       = module.greengrass_core_hanoi_site_001.thing_name
    thing_group      = local.hanoi_site_thing_group
    region           = local.region
    iot_endpoint     = module.greengrass_core_hanoi_site_001.iot_endpoint
    creds_endpoint   = data.aws_iot_endpoint.credentials.endpoint_address
    policy_name      = local.greengrass_policy_name
    tes_role_name    = "GreengrassCoreTokenExchangeRole"
    tes_role_alias   = "GreengrassCoreTokenExchangeRoleAlias"
    cert_file        = "${module.greengrass_core_hanoi_site_001.credentials_path}/${module.greengrass_core_hanoi_site_001.thing_name}-certificate.pem.crt"
    private_key_file = "${module.greengrass_core_hanoi_site_001.credentials_path}/${module.greengrass_core_hanoi_site_001.thing_name}-private.pem.key"
    root_ca_file     = "${module.greengrass_core_hanoi_site_001.credentials_path}/AmazonRootCA1.pem"
  })

  filename        = "${path.module}/install-greengrass-core.sh"
  file_permission = "0755"

  depends_on = [
    module.greengrass_core_hanoi_site_001,
    local_file.deployment_config
  ]
}

# Create pre-installation checks script
resource "local_file" "pre_install_checks" {
  content = <<-EOT
    #!/bin/bash
    # Pre-installation Checks for Greengrass

    set -e

    echo "================================================"
    echo "Greengrass Pre-Installation Checks"
    echo "================================================"
    echo ""

    # Check Java
    echo "[1/7] Checking Java installation..."
    if command -v java &> /dev/null; then
        JAVA_VERSION=$(java -version 2>&1 | head -n 1 | awk -F '"' '{print $2}')
        echo "  ✓ Java installed: $JAVA_VERSION"
    else
        echo "  ✗ ERROR: Java not installed!"
        echo "  Install: sudo apt install openjdk-11-jdk -y"
        exit 1
    fi

    # Check ggc_user
    echo "[2/7] Checking ggc_user..."
    if id ggc_user &> /dev/null; then
        echo "  ✓ ggc_user exists"
    else
        echo "  ! Creating ggc_user..."
        sudo useradd --system --create-home ggc_user
        echo "  ✓ ggc_user created"
    fi

    # Check ggc_group
    echo "[3/7] Checking ggc_group..."
    if getent group ggc_group &> /dev/null; then
        echo "  ✓ ggc_group exists"
    else
        echo "  ! Creating ggc_group..."
        sudo groupadd --system ggc_group
        echo "  ✓ ggc_group created"
    fi

    # Check disk space
    echo "[4/7] Checking disk space..."
    AVAILABLE=$(df /greengrass 2>/dev/null | tail -1 | awk '{print $4}' || df / | tail -1 | awk '{print $4}')
    REQUIRED=1048576  # 1GB in KB
    if [ "$AVAILABLE" -gt "$REQUIRED" ]; then
        echo "  ✓ Sufficient disk space: $(($AVAILABLE / 1024))MB available"
    else
        echo "  ⚠ WARNING: Low disk space: $(($AVAILABLE / 1024))MB available"
    fi

    # Check network
    echo "[5/7] Checking network connectivity..."
    if ping -c 1 -W 2 amazonaws.com &> /dev/null; then
        echo "  ✓ Network connectivity OK"
    else
        echo "  ✗ ERROR: Cannot reach AWS services"
        exit 1
    fi

    # Check AWS CLI
    echo "[6/7] Checking AWS CLI..."
    if command -v aws &> /dev/null; then
        AWS_VERSION=$(aws --version 2>&1 | cut -d' ' -f1)
        echo "  ✓ AWS CLI installed: $AWS_VERSION"
    else
        echo "  ✗ ERROR: AWS CLI not installed!"
        exit 1
    fi

    # Check current Greengrass
    echo "[7/7] Checking existing Greengrass installation..."
    if systemctl is-active --quiet greengrass.service 2>/dev/null; then
        echo "  ! Greengrass service is running"
        echo "  Current status:"
        sudo systemctl status greengrass.service --no-pager | head -5 | sed 's/^/    /'
    else
        echo "  ✓ No active Greengrass service"
    fi

    echo ""
    echo "================================================"
    echo "Pre-installation checks completed!"
    echo "================================================"
    echo ""
    echo "Ready to proceed with Greengrass installation."
  EOT

  filename        = "${path.module}/pre-install-checks.sh"
  file_permission = "0755"
}

# Outputs for installation
output "install_script" {
  description = "Path to Greengrass installation script"
  value       = local_file.greengrass_install_script.filename
}

output "pre_install_checks_script" {
  description = "Path to pre-installation checks script"
  value       = local_file.pre_install_checks.filename
}

output "installation_instructions" {
  description = "Instructions for running installation"
  value       = <<-EOT

  ================================================================
  🔧 GREENGRASS REINSTALLATION INSTRUCTIONS
  ================================================================

  Thing Name:  ${module.greengrass_core_hanoi_site_001.thing_name}
  Region:      ${local.region}
  Policy:      ${local.greengrass_policy_name}
  Thing Group: ${local.hanoi_site_thing_group}

  📋 STEP-BY-STEP GUIDE:

  1. Run pre-installation checks:
     cd ${path.module}
     ./pre-install-checks.sh

  2. Review installation script:
     cat install-greengrass-core.sh

  3. Run installation (this will backup and reinstall):
     sudo ./install-greengrass-core.sh

  4. Verify installation:
     sudo systemctl status greengrass.service
     sudo /greengrass/v2/bin/greengrass-cli component list

  5. Check connectivity:
     sudo tail -f /greengrass/v2/logs/greengrass.log

  ================================================================
  ⚠️  IMPORTANT NOTES:
  - This will STOP and BACKUP current Greengrass installation
  - Backup location: /greengrass/v2.backup-<timestamp>
  - New credentials are already in: ${module.greengrass_core_hanoi_site_001.credentials_path}/
  - Installation uses existing certificates (no new provisioning)
  ================================================================

  EOT
}
