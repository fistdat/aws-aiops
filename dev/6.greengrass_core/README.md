# AWS IoT Greengrass Core - Edge Layer Infrastructure

This directory contains the complete AWS IoT Greengrass edge layer infrastructure, including custom components, database layer, Zabbix integration, and deployment automation.

## Current Deployment Status

**Phase 2 - COMPLETE** (Architecture v2.0)

- **Hanoi Site 001**: Pilot site with 15,000 cameras
  - Thing Name: `GreengrassCore-site001-hanoi`
  - Thing Group: `Hanoi-Site-001`
  - Policy: `greengrass-core-policy`
  - Deployment: All components running and healthy

### Architecture v2.0 Highlights

- 95% reduction in cloud messaging (batch analytics)
- Edge database (SQLite) with schema v3.0
- Zabbix webhook integration (v4 - production ready)
- 4 custom Greengrass components deployed
- 5 DynamoDB tables (including AI chatbot ready)
- 100% Infrastructure as Code

## Prerequisites

Before running this module:

1. ✅ `dev/2.iot_core` must be deployed (creates Thing Groups and Policies)
2. ✅ AWS CLI configured with ap-southeast-1 region
3. ✅ Terraform >= 1.5.0 installed

## Directory Structure

See [DIRECTORY_STRUCTURE.md](./DIRECTORY_STRUCTURE.md) for complete directory organization.

```
6.greengrass_core/
├── terraform/              # Terraform Infrastructure as Code
├── edge-components/        # Greengrass Custom Components (4 components)
├── edge-database/          # Database Infrastructure Layer (SQLite)
├── zabbix-integration/     # Zabbix Webhook Integration
├── scripts/                # Setup & Utility Scripts
├── docs/                   # Deployment Documentation
├── deployments/            # Deployment Artifacts & Plans
├── installers/             # Installation Packages (Zabbix 7.4.5)
└── README.md               # This file
```

## Deployment Steps

### Fresh Installation

#### 1. Initialize Terraform

```bash
cd /home/sysadmin/2025/aismc/aws-aiops/dev/6.greengrass_core/terraform
terraform init
```

#### 2. Review Plan

```bash
terraform plan -out=../deployments/plans/tfplan
```

Expected resources:
- IoT Thing, Certificate, and Policies
- 4 Greengrass Components (webhook, forwarder, registry sync, analytics)
- Edge database (SQLite with schema v3.0)
- Zabbix webhook integration
- DynamoDB tables (v2.0 architecture)

#### 3. Apply Configuration

```bash
terraform apply ../deployments/plans/tfplan
```

#### 4. View Outputs

```bash
terraform output -json | jq
```

## Post-Deployment

After successful deployment:

### 1. Read Setup Instructions

```bash
cat docs/GREENGRASS-SETUP-INSTRUCTIONS.md
```

### 2. Install Greengrass Core (if not already installed)

```bash
cd scripts
./pre-install-checks.sh
sudo ./install-greengrass-core.sh
```

### 3. Verify Component Health

```bash
# Check webhook endpoint
curl -s http://localhost:8081/health | python3 -m json.tool

# View component logs
sudo tail -f /greengrass/v2/logs/com.aismc.ZabbixEventSubscriber.log

# Check database
sudo sqlite3 /var/greengrass/database/greengrass.db "SELECT * FROM cameras LIMIT 5"
```

## Greengrass Components

Four custom components are deployed:

### 1. ZabbixEventSubscriber (v1.0.0)
- **Purpose**: Webhook receiver for Zabbix events
- **Port**: 8081
- **Health Check**: `http://localhost:8081/health`
- **Source**: `edge-components/zabbix-event-subscriber/`

### 2. IncidentMessageForwarder (v1.0.0)
- **Purpose**: Cloud sync (disabled in v2.0 for batch analytics)
- **Source**: `edge-components/incident-message-forwarder/`

### 3. ZabbixHostRegistrySync (v1.0.0)
- **Purpose**: Device inventory sync to DynamoDB
- **Interval**: Hourly
- **Source**: `edge-components/zabbix-host-registry-sync/`

### 4. IncidentAnalyticsSync (v1.0.0)
- **Purpose**: Batch analytics aggregation to DynamoDB
- **Interval**: Hourly
- **Source**: `edge-components/incident-analytics-sync/`

## Edge Database

SQLite database with schema v3.0:

```bash
# Location
/var/greengrass/database/greengrass.db

# Schema
edge-database/schema/schema_update_v3.sql

# Tables
- cameras (v3: renamed from devices, NGSI-LD compliant)
- incidents
- messages
- registry_sync_status
```

## Zabbix Integration

Zabbix webhook integration for camera offline detection:

### Webhook Configuration

```bash
# Webhook endpoint
http://localhost:8081/zabbix/events

# Webhook script (production v4)
zabbix-integration/templates/webhook-script-v4-message.js

# Setup automation
cd zabbix-integration/scripts
./zabbix-webhook-setup.sh
```

### Media Type Configuration (Zabbix UI)

1. Administration → Media types → Create media type
2. Name: `Greengrass Webhook`
3. Type: `Webhook`
4. Script: Use webhook-script-v4-message.js
5. Test: `./verify-webhook.sh`

### Documentation

- `zabbix-integration/docs/ZABBIX_WEBHOOK_SETUP.md`
- `zabbix-integration/docs/ZABBIX_INTEGRATION_STATUS.md`

## Installation Packages

### Zabbix 7.4.5 Installer

Automated Zabbix installation from source:

```bash
cd installers
terraform init
terraform plan
terraform apply

# Post-installation
sudo systemctl start zabbix-server
./post-install-greengrass-integration.sh
```

Features:
- Full source compilation with all dependencies
- MySQL/MariaDB database setup
- Apache web frontend
- Systemd service configuration
- Greengrass webhook integration ready

See: `installers/zabbix-installer.tf` and `installers/README.md`

## Credentials Security

Credentials are stored securely:

1. **AWS SSM Parameter Store** (encrypted, production)
   - `/greengrass/GreengrassCore-site001-hanoi/cert-pem`
   - `/greengrass/GreengrassCore-site001-hanoi/private-key`

2. **Local Files** (initial setup only, gitignored)
   - `greengrass-credentials/` directory
   - File permissions: 0600 (owner read/write only)

## Troubleshooting

### Component Issues

**Check component status:**
```bash
ps aux | grep -E "(webhook_server|analytics_sync)" | grep -v grep
sudo /greengrass/v2/bin/greengrass-cli component list
```

**View component logs:**
```bash
sudo tail -f /greengrass/v2/logs/com.aismc.ZabbixEventSubscriber.log
sudo tail -f /greengrass/v2/logs/com.aismc.IncidentAnalyticsSync.log
```

### Database Issues

**Check database health:**
```bash
sudo sqlite3 /var/greengrass/database/greengrass.db "PRAGMA integrity_check;"
sudo sqlite3 /var/greengrass/database/greengrass.db "SELECT COUNT(*) FROM cameras;"
```

**Migration issues:**
```bash
# Check schema version
sudo sqlite3 /var/greengrass/database/greengrass.db ".schema cameras"

# Verify v3.0 migration
cd scripts
./migrate-cameras-to-devices.sh
```

### Zabbix Webhook Issues

**Test webhook endpoint:**
```bash
curl -s http://localhost:8081/health | python3 -m json.tool
cd zabbix-integration/scripts
./verify-webhook.sh
```

**Check Zabbix server:**
```bash
sudo systemctl status zabbix-server
sudo tail -f /var/log/zabbix/zabbix_server.log
```

### Infrastructure Issues

**Thing Group not found:**
```bash
cd ../../2.iot_core
terraform apply
```

**Policy not found:**
```bash
aws iot get-policy --policy-name greengrass-core-policy --region ap-southeast-1
```

## Cleanup

To remove all resources:

```bash
cd terraform
terraform destroy
```

⚠️ **Warning**: This will:
- Delete the IoT Thing and certificates
- Remove Greengrass components
- Remove SSM parameters
- Keep local files (manual deletion required)
- Keep Zabbix installation (uninstall separately)

## Module Dependencies

```
dev/1.vpc_networking
    ↓
dev/2.iot_core (Thing Groups, Policies)
    ↓
dev/6.greengrass_core (Things, Certificates, Components)
    ↓
dev/3.data_layer (DynamoDB v2.0)
```

## Deployment History

### Version 3.0 (2026-01-02)
- Directory reorganization
- Zabbix installer terraform
- Documentation updates
- Database migration v3.0

### Version 2.0 (2025-12-31)
- Batch analytics architecture
- 95% reduction in cloud messaging
- DynamoDB tables v2.0
- Zabbix webhook integration v4

### Version 1.0 (2025-12-30)
- Initial deployment
- 4 Greengrass components
- Edge database (SQLite)
- Real-time incident forwarding

## Next Steps (Phase 3)

### Priority 1: Production Hardening
- [ ] Configure CloudWatch monitoring
- [ ] Set up automated backups
- [ ] Implement security scanning
- [ ] Load testing

### Priority 2: Analytics & Visualization
- [ ] Deploy Grafana dashboards
- [ ] Site overview dashboard
- [ ] Incident analytics dashboard
- [ ] Device health monitoring

### Priority 3: AI Chatbot
- [ ] Request Bedrock access (Claude 3.5 Sonnet)
- [ ] Deploy Bedrock Agent + Lambda
- [ ] Integrate with chat_history DynamoDB table
- [ ] Test natural language queries

## Documentation

### Main Documents
- `README.md` - This file
- `DIRECTORY_STRUCTURE.md` - Directory organization
- `docs/PHASE2_DEPLOYMENT_COMPLETE.md` - Phase 2 status
- `docs/MIGRATION_V3_COMPLETE.md` - Database migration v3.0

### Component Documentation
- `edge-components/*/README.md` - Component-specific docs
- `zabbix-integration/docs/` - Zabbix integration guides
- `installers/README.md` - Installation packages

### Deployment Documentation
- `docs/DEPLOYMENT-SESSION-SUMMARY.md` - Deployment logs
- `docs/EDGE-COMPONENTS-DEPLOYMENT.md` - Component deployment
- `docs/GREENGRASS-SETUP-INSTRUCTIONS.md` - Setup guide

## Support

For issues:
- **Terraform State**: `cd terraform && terraform show`
- **AWS IoT Console**: https://ap-southeast-1.console.aws.amazon.com/iot/home
- **Greengrass Logs**: `/greengrass/v2/logs/`
- **Component Health**: `curl http://localhost:8081/health`
- **Documentation**: See `docs/` directory

## Quick Reference

```bash
# Component health
curl -s http://localhost:8081/health | python3 -m json.tool

# View logs
sudo tail -f /greengrass/v2/logs/com.aismc.*.log

# Database query
sudo sqlite3 /var/greengrass/database/greengrass.db \
  "SELECT * FROM incidents ORDER BY detected_at DESC LIMIT 10"

# Zabbix status
sudo systemctl status zabbix-server

# Greengrass status
sudo systemctl status greengrass
sudo /greengrass/v2/bin/greengrass-cli component list
```

---

**Version**: 3.0
**Last Updated**: 2026-01-03
**Status**: Phase 2 Complete - Production Ready
**Maintained By**: DevOps Team
