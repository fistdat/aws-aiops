# PRECONFIG: Terraform Structure for Week 1-2

## Overview

This document outlines the complete directory structure and preconfig files needed for Week 1-2 AWS Infrastructure Setup.

---

## Directory Structure

```
cluster-nonprod-iac-main/
│
├── ops/                                    # Operations layer
│   ├── 0.init_s3_backend/                  ✅ Existing - S3 for Terraform state
│   │   ├── main.tf
│   │   ├── locals.tf
│   │   ├── provider.tf
│   │   └── s3.tf
│   │
│   └── 1.organization/                     ⭐ NEW - AWS Organization setup
│       ├── main.tf                         → AWS Organization + accounts
│       ├── locals.tf                       → Common variables
│       ├── provider.tf                     → AWS provider config
│       └── outputs.tf                      → Account IDs, org ARN
│
├── dev/                                    # Development environment
│   ├── 0.iam_assume_role_terraform/        ✅ Existing - Base IAM
│   │   ├── main.tf
│   │   ├── provider.tf
│   │   ├── output.tf
│   │   └── iot_roles.tf                    ⭐ NEW - IoT-specific roles
│   │
│   ├── 0.key_pair/                         ✅ Existing - SSH keys
│   │   ├── main.tf
│   │   ├── locals.tf
│   │   ├── provider.tf
│   │   └── outputs.tf
│   │
│   ├── 1.networking/                       ✅ Existing - VPC setup
│   │   ├── main.tf
│   │   ├── locals.tf
│   │   ├── provider.tf
│   │   └── outputs.tf
│   │
│   ├── 2.iot_core/                         ⭐ NEW - AWS IoT Core
│   │   ├── main.tf                         → Thing Groups hierarchy
│   │   ├── iot_policies.tf                 → IoT Policies (Greengrass, read-only)
│   │   ├── certificates.tf                 → Certificate infrastructure
│   │   ├── data.tf                         → IoT endpoints data sources
│   │   ├── locals.tf                       → Local variables
│   │   ├── provider.tf                     → AWS provider
│   │   └── outputs.tf                      → Thing Groups, policies, endpoints
│   │
│   ├── 3.data_layer/                       ⭐ NEW - Data storage
│   │   ├── dynamodb.tf                     → DeviceRegistry + CameraIncidents
│   │   ├── timestream.tf                   → Timestream database + tables
│   │   ├── locals.tf
│   │   ├── provider.tf
│   │   └── outputs.tf                      → Table names, DB ARNs
│   │
│   ├── 4.iot_rules/                        ⭐ NEW - Integration layer
│   │   ├── main.tf                         → IoT Rules Engine
│   │   ├── sns.tf                          → SNS topics for alerts
│   │   ├── variables.tf                    → Alert email config
│   │   ├── locals.tf
│   │   ├── provider.tf
│   │   └── outputs.tf                      → Rule ARNs, topic ARNs
│   │
│   └── 5.api_gateway/                      ⭐ NEW - API layer
│       ├── main.tf                         → API Gateway resources
│       ├── lambda.tf                       → Lambda functions
│       ├── lambda/
│       │   ├── get_cameras/
│       │   │   ├── index.py                → Lambda code for GET /cameras
│       │   │   └── requirements.txt
│       │   └── get_incidents/
│       │       ├── index.py                → Lambda code for GET /incidents
│       │       └── requirements.txt
│       ├── locals.tf
│       ├── provider.tf
│       └── outputs.tf                      → API endpoint, Lambda ARNs
│
├── _module/                                # Reusable Terraform modules
│   └── aws/
│       ├── networking/
│       │   └── vpc/                        ✅ Existing - VPC module
│       │       ├── main.tf
│       │       ├── variables.tf
│       │       ├── outputs.tf
│       │       └── README.md
│       │
│       ├── iot/                            ⭐ NEW - IoT modules
│       │   ├── thing_group/
│       │   │   ├── main.tf                 → Thing Group resource
│       │   │   ├── variables.tf            → Group name, parent, attrs
│       │   │   └── outputs.tf              → Group ARN, name
│       │   │
│       │   └── iot_policy/
│       │       ├── main.tf                 → IoT Policy resource
│       │       ├── variables.tf            → Policy name, document
│       │       └── outputs.tf              → Policy ARN, name
│       │
│       ├── data/                           ⭐ NEW - Data modules
│       │   ├── dynamodb/
│       │   │   ├── main.tf                 → DynamoDB table
│       │   │   ├── variables.tf            → Table config, GSIs
│       │   │   └── outputs.tf              → Table name, ARN
│       │   │
│       │   └── timestream/                 # Optional module (inline for now)
│       │
│       └── integration/                    # Optional modules (inline for now)
│
├── scripts/                                ⭐ NEW - Automation scripts
│   ├── deploy-week1-2.sh                   → Full deployment automation
│   ├── validate-infrastructure.sh          → Infrastructure validation
│   ├── create-iot-certificate.sh           → Certificate generation
│   ├── build-lambda.sh                     → Lambda packaging
│   └── cleanup.sh                          → Resource cleanup
│
└── claudedocs/                             ⭐ NEW - Documentation
    ├── WEEK-1-2-INFRASTRUCTURE-PLAN.md     → Comprehensive plan
    ├── PRECONFIG-STRUCTURE.md              → This file
    ├── VALIDATION-CHECKLIST.md             → Test procedures
    ├── COST-ESTIMATION.md                  → Budget tracking
    ├── QUICK-REFERENCE.md                  → Common commands
    └── IMPLEMENTATION-CHECKLIST.md         → Task tracking
```

---

## Module Dependencies

### Deployment Order

```
1. ops/0.init_s3_backend
   ↓
2. ops/1.organization (optional for single account)
   ↓
3. dev/0.iam_assume_role_terraform + iot_roles.tf
   ↓
4. dev/1.networking (already exists, verify only)
   ↓
5. dev/2.iot_core
   ↓
6. dev/3.data_layer
   ↓
7. dev/4.iot_rules
   ↓
8. dev/5.api_gateway
```

### Cross-Module References

**dev/4.iot_rules/main.tf** depends on:
```hcl
data "terraform_remote_state" "iam" {
  # Gets: iot_core_service_role_arn
}

data "terraform_remote_state" "data_layer" {
  # Gets: device_registry_table_name
  # Gets: camera_incidents_table_name
  # Gets: timestream_database_name
}
```

**dev/5.api_gateway/lambda.tf** depends on:
```hcl
data "terraform_remote_state" "data_layer" {
  # Gets: device_registry_table_name
  # Gets: camera_incidents_table_name
}

data "terraform_remote_state" "iam" {
  # Gets: iot_lambda_role_arn
}
```

---

## Configuration Files Template

### Backend Configuration
**File**: `backend.tf` (in each module)

```hcl
terraform {
  backend "s3" {
    bucket         = "aismc-nonprod-terraform-state"
    key            = "dev/<module-name>/terraform.tfstate"
    region         = "ap-southeast-1"
    encrypt        = true
    dynamodb_table = "terraform-state-lock"
  }
}
```

### Provider Configuration
**File**: `provider.tf` (in each module)

```hcl
provider "aws" {
  region = "ap-southeast-1"

  default_tags {
    tags = local.tags
  }
}
```

### Locals Configuration
**File**: `locals.tf` (in each module)

```hcl
locals {
  product_name = "aismc"
  environment  = "dev"
  region       = "ap-southeast-1"

  tags = {
    Environment = local.environment
    Product     = local.product_name
    ManagedBy   = "Terraform"
    Project     = "AIOps-IoC"
  }
}
```

---

## Key Resources Summary

### IoT Core (dev/2.iot_core)
```
Resources Created:
- 1 Root Thing Group (Vietnam)
- 3 Regional Thing Groups (Northern, Central, Southern)
- 1 Site Thing Group (Hanoi-Site-001)
- 2 IoT Policies (greengrass-core-policy, readonly-policy)
- 1 S3 Bucket (certificate metadata)
- 1 DynamoDB Table (certificate registry)
```

### Data Layer (dev/3.data_layer)
```
Resources Created:
- 2 DynamoDB Tables
  • device-registry (hash: entity_id, GSI: site_id, device_type)
  • camera-incidents (hash: incident_id, range: timestamp, 4 GSIs)
- 1 Timestream Database (iot-metrics)
- 3 Timestream Tables
  • camera-metrics
  • site-metrics
  • system-metrics
```

### IoT Rules (dev/4.iot_rules)
```
Resources Created:
- 4 IoT Topic Rules
  • incidents_to_dynamodb
  • registry_to_dynamodb
  • critical_alerts_to_sns
  • metrics_to_timestream
- 3 SNS Topics
  • critical-alerts
  • warning-alerts
  • operational-notifications
- 1 CloudWatch Log Group (rule errors)
```

### API Gateway (dev/5.api_gateway)
```
Resources Created:
- 1 REST API Gateway
- 3 API Resources (/cameras, /incidents, /metrics)
- 2 Lambda Functions
  • get-cameras
  • get-incidents
- 1 API Stage (dev)
- 2 CloudWatch Log Groups (Lambda logs)
```

---

## Variables Configuration

### Global Variables
**File**: `terraform.tfvars` (in each module)

```hcl
# Common variables
region       = "ap-southeast-1"
product_name = "aismc"
environment  = "dev"

# IoT Rules specific
alert_email = "aiops-alerts@aismc.vn"

# API Gateway specific
api_stage = "dev"
```

---

## Outputs Reference

### dev/2.iot_core/outputs.tf
```hcl
output "vietnam_thing_group_arn"
output "hanoi_site_001_thing_group_arn"
output "greengrass_core_policy_name"
output "iot_data_endpoint"
output "iot_credentials_endpoint"
output "certificate_bucket_name"
```

### dev/3.data_layer/outputs.tf
```hcl
output "device_registry_table_name"
output "camera_incidents_table_name"
output "timestream_database_name"
output "timestream_tables" # Map of table names
```

### dev/4.iot_rules/outputs.tf
```hcl
output "iot_rules" # Map of rule ARNs
output "sns_topics" # Map of topic ARNs
```

### dev/5.api_gateway/outputs.tf
```hcl
output "api_gateway_endpoint"
output "lambda_functions" # Map of function ARNs
```

---

## Preconfig Checklist

Before starting deployment:

### Prerequisites
- [ ] AWS CLI installed (version 2.x)
- [ ] Terraform installed (version 1.5+)
- [ ] AWS credentials configured
- [ ] Git repository cloned
- [ ] Python 3.11+ installed (for Lambda)
- [ ] jq installed (for validation scripts)

### File Creation
- [ ] All module directories created
- [ ] All .tf files created from templates
- [ ] All Lambda Python files created
- [ ] All scripts created and made executable
- [ ] All documentation created

### Configuration
- [ ] backend.tf configured in each module
- [ ] locals.tf values correct for environment
- [ ] Variables defined with defaults
- [ ] Email address configured for SNS alerts

### Validation
- [ ] Terraform fmt on all .tf files
- [ ] Terraform validate on each module
- [ ] Scripts syntax checked (shellcheck)
- [ ] Python code linted (flake8)

---

## Quick Start Commands

```bash
# 1. Clone template repository
git clone <cluster-nonprod-iac-main> aiops-iot-infrastructure
cd aiops-iot-infrastructure

# 2. Create new module directories
mkdir -p ops/1.organization
mkdir -p dev/2.iot_core dev/3.data_layer dev/4.iot_rules dev/5.api_gateway
mkdir -p dev/5.api_gateway/lambda/{get_cameras,get_incidents}
mkdir -p _module/aws/iot/{thing_group,iot_policy}
mkdir -p _module/aws/data/dynamodb
mkdir -p scripts claudedocs

# 3. Make scripts executable
chmod +x scripts/*.sh

# 4. Initialize S3 backend
cd ops/0.init_s3_backend
terraform init
terraform apply

# 5. Deploy infrastructure
cd ../../..
./scripts/deploy-week1-2.sh

# 6. Validate deployment
./scripts/validate-infrastructure.sh
```

---

## Cost Tracking

### Expected Costs by Module

| Module | Resources | Monthly Cost |
|--------|-----------|--------------|
| ops/1.organization | AWS Org, Accounts | $0 |
| dev/0.iam_assume_role_terraform | IAM Roles | $0 |
| dev/2.iot_core | Thing Groups, Policies | $0 |
| dev/3.data_layer | DynamoDB (empty), Timestream (empty) | $0-4 |
| dev/4.iot_rules | IoT Rules, SNS | $0-1 |
| dev/5.api_gateway | API GW, Lambda (free tier) | $0 |
| **Total** | | **$0-6/month** |

---

## Security Considerations

### IAM Least Privilege
- IoT Core service role: DynamoDB write only
- Greengrass Core role: Minimal Greengrass permissions
- Lambda role: DynamoDB read/write to specific tables

### Encryption
- S3 buckets: AES-256 encryption at rest
- DynamoDB: Default encryption
- Timestream: Default encryption
- Data in transit: TLS 1.3 for all connections

### Network Security
- VPC: Private subnets for compute
- NAT Gateways: Outbound only
- Security Groups: Restrictive ingress rules
- IoT Policies: Topic-level restrictions

---

## Troubleshooting Guide

### Common Issues

**Issue**: S3 backend state lock
```bash
# Solution
cd <module-dir>
terraform force-unlock <LOCK_ID>
```

**Issue**: Module not found
```bash
# Solution
cd <module-dir>
terraform get -update
```

**Issue**: Invalid credentials
```bash
# Solution
aws sts get-caller-identity
aws configure list
```

**Issue**: Resource already exists
```bash
# Solution - Import existing resource
terraform import <resource_type>.<name> <resource_id>
```

---

## Next Steps After Week 1-2

1. **Certificate Generation**
   - Use scripts/create-iot-certificate.sh
   - Create certificate for pilot site
   - Store in S3 and DynamoDB

2. **Week 3 Preparation**
   - Setup Greengrass Core environment
   - Develop SQLite database schema
   - Prepare component development workspace

3. **Testing Environment**
   - Setup local Greengrass for development
   - Mock DMP API responses
   - Prepare SmartHUB simulator

---

**Document Version**: 1.0
**Last Updated**: 2025-12-29
**Status**: Ready for Implementation
