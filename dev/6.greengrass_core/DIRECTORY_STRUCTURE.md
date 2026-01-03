# Directory Structure - Greengrass Core (6.greengrass_core)

**Last Updated**: 2026-01-02
**Schema Version**: v3.0
**Status**: Reorganized for better management

---

## Overview

This directory contains all AWS IoT Greengrass edge layer infrastructure, including components, database, Zabbix integration, and deployment artifacts.

---

## Directory Structure

```
6.greengrass_core/
├── terraform/                  # Terraform Infrastructure as Code
│   ├── main.tf                # Main Greengrass deployment
│   ├── deployment.tf          # Component deployments
│   ├── edge-components.tf     # Edge components configuration
│   ├── edge-database.tf       # Database setup
│   ├── database-migration-v3.tf    # DB migration v3.0
│   ├── greengrass-components.tf    # Component definitions
│   ├── greengrass-install.tf       # Greengrass installation
│   ├── locals.tf              # Local variables
│   ├── outputs.tf             # Output values
│   ├── provider.tf            # AWS provider config
│   └── *.tf.backup            # Backup files
│
├── edge-components/            # Greengrass Custom Components
│   ├── zabbix-event-subscriber/    # Webhook receiver (v1.0.0)
│   │   ├── recipe.yaml
│   │   ├── src/webhook_server.py
│   │   ├── requirements.txt
│   │   └── README.md
│   │
│   ├── incident-message-forwarder/ # Cloud sync (v1.0.0)
│   │   ├── recipe.yaml
│   │   ├── src/forwarder_service.py
│   │   └── requirements.txt
│   │
│   ├── zabbix-host-registry-sync/  # Device inventory (v1.0.0)
│   │   ├── recipe.yaml
│   │   ├── src/sync_service.py
│   │   └── requirements.txt
│   │
│   ├── incident-analytics-sync/    # Analytics (v1.0.0)
│   │   ├── recipe.yaml
│   │   └── src/analytics_sync.py
│   │
│   ├── python-dao/             # Data Access Objects
│   │   ├── dao.py
│   │   ├── connection.py
│   │   └── camera_dao_v3.py
│   │
│   ├── database/               # Database schemas
│   │   └── schema.sql          # v3.0.0 schema
│   │
│   └── scripts/                # Component setup scripts
│       ├── install-python-dao.sh
│       ├── setup-database.sh
│       └── test-database.py
│
├── edge-database/              # Database Infrastructure Layer
│   ├── schema/
│   │   ├── schema_update_v2.sql    # v2.0 migration (deprecated)
│   │   └── schema_update_v3.sql    # v3.0 migration
│   │
│   ├── src/
│   │   ├── database/           # Core database modules
│   │   │   ├── connection.py
│   │   │   ├── dao.py
│   │   │   └── device_dao.py
│   │   └── utils/              # Utility functions
│   │       └── ngsi_ld.py
│   │
│   ├── tests/                  # Database tests
│   │   ├── test_database.py
│   │   └── test_device_dao.py
│   │
│   └── scripts/
│       └── verify_dao.sh
│
├── zabbix-integration/         # Zabbix Webhook Integration
│   ├── templates/              # Webhook scripts
│   │   ├── webhook-script-v2.js
│   │   ├── webhook-script-v3-debug.js
│   │   └── webhook-script-v4-message.js    # ← Production (v4)
│   │
│   ├── scripts/                # Setup automation
│   │   ├── zabbix-webhook-setup.sh
│   │   └── verify-webhook.sh
│   │
│   ├── terraform/              # Zabbix IaC
│   │   └── zabbix-webhook-fixes.tf
│   │
│   ├── docs/                   # Integration documentation
│   │   ├── ZABBIX_WEBHOOK_SETUP.md
│   │   ├── ZABBIX_INTEGRATION_STATUS.md
│   │   ├── ZABBIX_WEBHOOK_INTEGRATION_SUMMARY.md
│   │   └── IAC_WEBHOOK_DEPLOYMENT_COMPLETE.md
│   │
│   ├── IaC_RULES_ANALYSIS.md
│   └── README.md
│
├── scripts/                    # Setup & Utility Scripts
│   ├── install-greengrass-core.sh       # Greengrass installation
│   ├── copy-credentials-to-greengrass.sh
│   ├── pre-install-checks.sh
│   ├── verify-webhook.sh
│   └── migrate-cameras-to-devices.sh    # DB migration v3.0
│
├── templates/                  # Terraform Templates
│   └── edge-components-summary.tpl
│
├── docs/                       # Documentation
│   ├── DEPLOYMENT-SESSION-SUMMARY.md    # Deployment logs
│   ├── DEPLOYMENT-SUMMARY.md
│   ├── EDGE-COMPONENTS-DEPLOYMENT.md    # Component deployment
│   ├── GREENGRASS-SETUP-INSTRUCTIONS.md # Setup guide
│   ├── MIGRATION_SUMMARY.md             # Migration summary
│   ├── MIGRATION_V3_COMPLETE.md         # v3.0 migration report
│   ├── PHASE2_DEPLOYMENT_COMPLETE.md    # Phase 2 status
│   └── SCHEMA_UPDATE_SUMMARY.md         # Schema updates
│
├── deployments/                # Deployment Artifacts
│   ├── results/                # Deployment result JSONs
│   │   ├── deployment-result.json
│   │   ├── deployment-result-v2.json
│   │   ├── deployment-result-fixed.json
│   │   ├── deployment-result-local.json
│   │   ├── deployment-result-analytics-fix.json
│   │   ├── edge-components-deployment.json
│   │   ├── edge-components-deployment-v2.json
│   │   ├── edge-components-deployment-fixed.json
│   │   ├── cli-deployment.json
│   │   └── cli-deployment-result.json
│   │
│   └── plans/                  # Terraform Plans
│       ├── tfplan-deployment
│       ├── tfplan-edge-components
│       ├── tfplan-edge-v2
│       ├── tfplan-edge-v2-deployment
│       ├── tfplan-dao-layer
│       ├── tfplan-dao-v2
│       ├── tfplan-dao-fix
│       ├── tfplan-dao-zabbix-fix
│       ├── tfplan-flask
│       ├── tfplan-forwarder
│       ├── tfplan-full
│       ├── tfplan-iac-compliance
│       ├── tfplan-phase2-zabbix-integration
│       ├── tfplan-recovery-fix
│       ├── tfplan-registry-sync
│       ├── tfplan-schema-v2
│       ├── tfplan-timestamp-fix
│       ├── tfplan-webhook
│       ├── tfplan-webhook-fix-v2
│       ├── tfplan-webhook-fix-v3
│       ├── tfplan-webhook-fixes
│       ├── tfplan-webhook-script-fix
│       └── tfplan-webhook-v4-fix
│
├── installers/                 # Installation Packages
│   ├── zabbix-7.4.5/          # Zabbix source code
│   └── README.md               # Installation instructions
│
├── greengrass-credentials/     # Greengrass Certificates (gitignored)
│   ├── *.pem
│   └── *.key
│
├── .gitignore                  # Git ignore rules
├── .terraform/                 # Terraform plugins (gitignored)
├── terraform.tfstate           # Terraform state (keep in root)
├── terraform.tfstate.backup    # State backup
├── DIRECTORY_STRUCTURE.md      # This file
└── README.md                   # Main documentation
```

---

## File Organization Guidelines

### What Goes Where

#### `terraform/`
- ✅ All `*.tf` files
- ✅ Terraform configuration
- ✅ Infrastructure definitions
- ❌ No deployment results
- ❌ No temporary files

#### `edge-components/`
- ✅ Component source code
- ✅ Recipe YAML files
- ✅ Requirements files
- ✅ Component-specific READMEs
- ❌ No deployment artifacts

#### `edge-database/`
- ✅ Database schemas
- ✅ DAO layer code
- ✅ Database utilities
- ✅ Tests
- ❌ No actual database files

#### `zabbix-integration/`
- ✅ Webhook scripts
- ✅ Integration documentation
- ✅ Setup automation
- ❌ No Zabbix binaries (use installers/)

#### `scripts/`
- ✅ Reusable shell scripts
- ✅ Setup automation
- ✅ Utility scripts
- ❌ No component-specific scripts (use edge-components/<component>/scripts/)

#### `docs/`
- ✅ Deployment documentation
- ✅ Migration reports
- ✅ Status summaries
- ✅ Setup instructions
- ❌ No code or configurations

#### `deployments/results/`
- ✅ Deployment result JSONs
- ✅ Deployment logs
- ✅ Temporary deployment artifacts
- ⚠️  Can be cleaned periodically

#### `deployments/plans/`
- ✅ Terraform plan files
- ✅ tfplan-* files
- ⚠️  Can be cleaned after successful deployment

#### `installers/`
- ✅ Installation source code
- ✅ Installation packages
- ✅ Dependency installers
- ❌ No build artifacts

---

## Maintenance

### Cleanup Temporary Files

```bash
# Remove old deployment results (keep last 5)
cd deployments/results
ls -t | tail -n +6 | xargs rm -f

# Remove old terraform plans
cd deployments/plans
rm -f tfplan-*

# Clean Terraform cache (if needed)
cd terraform
rm -rf .terraform/
```

### Backup Important Files

```bash
# Backup Terraform state
cp terraform.tfstate terraform.tfstate.backup-$(date +%Y%m%d)

# Backup database
sudo cp /var/greengrass/database/greengrass.db \
  /var/greengrass/database/greengrass.db.backup-$(date +%Y%m%d)
```

---

## Quick Reference

### Run Terraform

```bash
cd terraform
terraform init
terraform plan -out=../deployments/plans/tfplan
terraform apply ../deployments/plans/tfplan
```

### Deploy Component

```bash
cd edge-components/<component-name>
# Edit recipe.yaml
# Deploy via Terraform (terraform/edge-components.tf)
```

### Check Component Health

```bash
# Webhook server
curl -s http://localhost:8081/health | python3 -m json.tool

# View logs
sudo tail -f /greengrass/v2/logs/com.aismc.ZabbixEventSubscriber.log

# Database query
sudo sqlite3 /var/greengrass/database/greengrass.db \
  "SELECT * FROM cameras LIMIT 5"
```

---

## Version History

| Version | Date | Changes |
|---------|------|---------|
| 3.0 | 2026-01-02 | Directory reorganization, added installers/, docs/, deployments/ |
| 2.0 | 2025-12-31 | Added edge-database/, zabbix-integration/ |
| 1.0 | 2025-12-30 | Initial structure with terraform/ and edge-components/ |

---

**Maintained By**: DevOps Team
**Schema Version**: v3.0
**Last Reorganization**: 2026-01-02
