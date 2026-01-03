# Installation Packages

This directory contains installation packages and source code for infrastructure dependencies.

## Contents

### Zabbix 7.4.5

**Directory**: `zabbix-7.4.5/`
**Version**: 7.4.5
**Purpose**: Zabbix server installation source code

#### Option 1: Automated Installation (Recommended)

Use the Terraform-based installer for automated deployment:

```bash
cd /home/sysadmin/2025/aismc/aws-aiops/dev/6.greengrass_core/installers

# Initialize Terraform
terraform init

# Review installation plan
terraform plan

# Apply installation (automated)
terraform apply

# Post-installation
sudo systemctl start zabbix-server
sudo systemctl enable zabbix-server
./post-install-greengrass-integration.sh
```

**Features**:
- Automated dependency installation
- MySQL/MariaDB database setup
- Full source compilation
- Apache web frontend configuration
- Systemd service creation
- Greengrass webhook integration ready

**See**: `zabbix-installer.tf` for complete automation

#### Option 2: Manual Installation

For manual installation or troubleshooting:

```bash
# Extract (if from tarball) or use existing directory
cd zabbix-7.4.5

# Configure
./configure --enable-server --enable-agent --with-mysql --with-libcurl \
    --with-libxml2 --with-net-snmp --with-ssh2 --with-openipmi

# Compile and install
make -j$(nproc)
sudo make install

# Setup database
mysql -u root -p
CREATE DATABASE zabbix CHARACTER SET utf8mb4 COLLATE utf8mb4_bin;
CREATE USER 'zabbix'@'localhost' IDENTIFIED BY 'password';
GRANT ALL PRIVILEGES ON zabbix.* TO 'zabbix'@'localhost';
FLUSH PRIVILEGES;

# Import schema
mysql -u zabbix -p zabbix < database/mysql/schema.sql
mysql -u zabbix -p zabbix < database/mysql/images.sql
mysql -u zabbix -p zabbix < database/mysql/data.sql
```

**Configuration files**:
- Server config: `/etc/zabbix/zabbix_server.conf`
- Agent config: `/etc/zabbix/zabbix_agentd.conf`
- Web frontend: Copy `ui/` to `/var/www/html/zabbix/`

**Integration with Greengrass**:
- Webhook endpoint: `http://localhost:8081/zabbix/events`
- Webhook script: See `../zabbix-integration/templates/webhook-script-v4-message.js`
- Media type: Greengrass Webhook (configured via Zabbix API)

#### Verification

After installation (automated or manual):

```bash
# Check Zabbix server
sudo systemctl status zabbix-server

# Access web UI
curl http://localhost/zabbix
# Default credentials: Admin / zabbix

# Verify Greengrass webhook
curl -s http://localhost:8081/health | python3 -m json.tool

# View logs
sudo tail -f /var/log/zabbix/zabbix_server.log
```

---

## Adding New Installers

When adding new installation packages:

1. **Create subdirectory**: `mkdir installers/<package-name>-<version>`
2. **Add README**: Document installation steps
3. **Update .gitignore**: Exclude large binaries if needed
4. **Document integration**: How it integrates with Greengrass

---

## Notes

- This directory is **excluded from .gitignore** to preserve installers
- Keep only stable, tested versions
- Document any custom patches or configurations
- Remove outdated versions after testing new ones

---

**Last Updated**: 2026-01-02
**Maintainer**: DevOps Team
