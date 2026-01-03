# WEEK 1-2: AWS INFRASTRUCTURE SETUP - DETAILED PLAN

## 📋 EXECUTIVE SUMMARY

**Duration**: 2 weeks (10 working days)
**Objective**: Setup complete AWS infrastructure foundation for AIOps IoC platform
**Target**: Support pilot deployment of 1 site with 15,000 cameras
**Terraform Template**: Based on `cluster-nonprod-iac-main` structure

---

## 🎯 SUCCESS CRITERIA

✅ AWS Organization with multi-account structure operational
✅ IAM roles and policies configured with least privilege
✅ AWS IoT Core configured with Thing Groups hierarchy
✅ DynamoDB tables created and indexed
✅ IoT Rules Engine routing messages correctly
✅ API Gateway + Lambda skeleton deployed
✅ All infrastructure code in Terraform
✅ CI/CD pipeline functional

---

## 📅 DETAILED TIMELINE

### **Day 1-2: Foundation Setup**
- AWS Organization structure
- IAM roles and policies
- S3 backend for Terraform state
- Network prerequisites

### **Day 3-5: IoT Core Infrastructure**
- Thing Groups hierarchy
- IoT Policies and certificates
- MQTT topic structure
- Device provisioning setup

### **Day 6-7: Data Layer**
- DynamoDB tables (DeviceRegistry, CameraIncidents)
- Timestream database
- Indexes and optimization

### **Day 8-9: Integration Layer**
- IoT Rules Engine
- SNS topics for alerting
- EventBridge rules

### **Day 10: API & Validation**
- API Gateway skeleton
- Lambda functions
- End-to-end validation

---

## 🏗️ TERRAFORM MODULE STRUCTURE

Based on existing template, we'll extend with new modules:

```
cluster-nonprod-iac-main/
├── ops/
│   ├── 0.init_s3_backend/          # ✅ Existing - S3 for state
│   └── 1.organization/             # ⭐ NEW - AWS Organization
│
├── dev/
│   ├── 0.iam_assume_role_terraform/  # ✅ Existing
│   ├── 0.key_pair/                   # ✅ Existing
│   ├── 1.networking/                 # ✅ Existing - VPC
│   ├── 2.iot_core/                   # ⭐ NEW - IoT Core setup
│   ├── 3.data_layer/                 # ⭐ NEW - DynamoDB + Timestream
│   ├── 4.iot_rules/                  # ⭐ NEW - Rules Engine
│   └── 5.api_gateway/                # ⭐ NEW - API + Lambda
│
└── _module/
    ├── aws/
    │   ├── networking/vpc/           # ✅ Existing
    │   ├── iot/
    │   │   ├── thing_group/          # ⭐ NEW
    │   │   ├── iot_policy/           # ⭐ NEW
    │   │   └── certificates/         # ⭐ NEW
    │   ├── data/
    │   │   ├── dynamodb/             # ⭐ NEW
    │   │   └── timestream/           # ⭐ NEW
    │   └── integration/
    │       ├── iot_rules/            # ⭐ NEW
    │       └── api_gateway/          # ⭐ NEW
```

---

## 📝 TASK BREAKDOWN BY DAY

## **DAY 1-2: FOUNDATION SETUP**

### Task 1.1: AWS Organization Structure
**File**: `ops/1.organization/main.tf`

**Requirements**:
- Master account: `aismc-master`
- Dev account: `aismc-dev`
- Prod account: `aismc-prod` (future)
- SCPs for security baseline

**Terraform Code**:
```hcl
# ops/1.organization/main.tf
resource "aws_organizations_organization" "main" {
  aws_service_access_principals = [
    "cloudtrail.amazonaws.com",
    "config.amazonaws.com",
    "iot.amazonaws.com"
  ]

  feature_set = "ALL"
}

resource "aws_organizations_account" "dev" {
  name      = "aismc-dev"
  email     = "aws-dev@aismc.vn"
  role_name = "OrganizationAccountAccessRole"

  tags = {
    Environment = "dev"
    ManagedBy   = "Terraform"
  }
}
```

**Validation**:
```bash
aws organizations describe-organization
aws organizations list-accounts
```

---

### Task 1.2: Enhanced IAM Roles
**File**: `dev/0.iam_assume_role_terraform/iot_roles.tf` (new)

**Requirements**:
- IoT Core service role
- Greengrass Core device role
- Lambda execution role for IoT Rules
- API Gateway execution role

**Terraform Code**:
```hcl
# dev/0.iam_assume_role_terraform/iot_roles.tf

# IoT Core Service Role
resource "aws_iam_role" "iot_core_service_role" {
  name = "${local.product_name}-${local.environment}-iot-core-service-role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Action = "sts:AssumeRole"
      Effect = "Allow"
      Principal = {
        Service = "iot.amazonaws.com"
      }
    }]
  })

  tags = local.tags
}

# Policy for IoT Core to write to DynamoDB
resource "aws_iam_role_policy" "iot_dynamodb_policy" {
  name = "iot-dynamodb-access"
  role = aws_iam_role.iot_core_service_role.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Action = [
          "dynamodb:PutItem",
          "dynamodb:UpdateItem"
        ]
        Resource = [
          "arn:aws:dynamodb:${var.region}:${data.aws_caller_identity.current.account_id}:table/${local.product_name}-${local.environment}-*"
        ]
      }
    ]
  })
}

# Greengrass Core Device Role
resource "aws_iam_role" "greengrass_core_role" {
  name = "${local.product_name}-${local.environment}-greengrass-core-role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Action = "sts:AssumeRole"
      Effect = "Allow"
      Principal = {
        Service = "credentials.iot.amazonaws.com"
      }
    }]
  })

  tags = local.tags
}

# Policy for Greengrass Core
resource "aws_iam_role_policy_attachment" "greengrass_core_policy" {
  role       = aws_iam_role.greengrass_core_role.name
  policy_arn = "arn:aws:iam::aws:policy/service-role/AWSGreengrassResourceAccessRolePolicy"
}

# Lambda Execution Role for IoT Rules
resource "aws_iam_role" "iot_lambda_role" {
  name = "${local.product_name}-${local.environment}-iot-lambda-role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Action = "sts:AssumeRole"
      Effect = "Allow"
      Principal = {
        Service = "lambda.amazonaws.com"
      }
    }]
  })

  tags = local.tags
}

# Lambda basic execution + DynamoDB access
resource "aws_iam_role_policy_attachment" "lambda_basic" {
  role       = aws_iam_role.iot_lambda_role.name
  policy_arn = "arn:aws:iam::aws:policy/service-role/AWSLambdaBasicExecutionRole"
}

resource "aws_iam_role_policy" "lambda_dynamodb_access" {
  name = "lambda-dynamodb-access"
  role = aws_iam_role.iot_lambda_role.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Effect = "Allow"
      Action = [
        "dynamodb:PutItem",
        "dynamodb:GetItem",
        "dynamodb:UpdateItem",
        "dynamodb:Query",
        "dynamodb:Scan"
      ]
      Resource = [
        "arn:aws:dynamodb:${var.region}:${data.aws_caller_identity.current.account_id}:table/${local.product_name}-${local.environment}-*"
      ]
    }]
  })
}

# Outputs
output "iot_core_service_role_arn" {
  value = aws_iam_role.iot_core_service_role.arn
}

output "greengrass_core_role_arn" {
  value = aws_iam_role.greengrass_core_role.arn
}

output "iot_lambda_role_arn" {
  value = aws_iam_role.iot_lambda_role.arn
}
```

**Validation**:
```bash
aws iam get-role --role-name aismc-dev-iot-core-service-role
aws iam get-role --role-name aismc-dev-greengrass-core-role
aws iam get-role --role-name aismc-dev-iot-lambda-role
```

---

### Task 1.3: Verify Existing Network Infrastructure
**File**: `dev/1.networking/` (already exists)

**Validation Checklist**:
```bash
# Check VPC
terraform -chdir=dev/1.networking output vpc_id
terraform -chdir=dev/1.networking output private_subnet_ids
terraform -chdir=dev/1.networking output public_subnet_ids

# Verify CIDR ranges match proposal
# Main CIDR: 10.246.136.0/22
# Public: 10.246.136.0/27, 10.246.136.32/27
# Private: 10.246.136.64/27, 10.246.136.96/27
```

**Notes**:
- VPC already configured with NAT gateways
- Subnets in 2 AZs for high availability
- No changes needed for IoT workload

---

## **DAY 3-5: AWS IOT CORE INFRASTRUCTURE**

### Task 2.1: Thing Groups Hierarchy Module
**File**: `_module/aws/iot/thing_group/main.tf`

**Purpose**: Create reusable module for Thing Groups

**Module Code**:
```hcl
# _module/aws/iot/thing_group/main.tf
variable "thing_group_name" {
  description = "Name of the Thing Group"
  type        = string
}

variable "parent_group_name" {
  description = "Parent Thing Group name (optional)"
  type        = string
  default     = ""
}

variable "description" {
  description = "Thing Group description"
  type        = string
  default     = ""
}

variable "attributes" {
  description = "Thing Group attributes"
  type        = map(string)
  default     = {}
}

variable "tags" {
  description = "Tags for Thing Group"
  type        = map(string)
  default     = {}
}

resource "aws_iot_thing_group" "this" {
  name = var.thing_group_name

  properties {
    description = var.description
    attribute_payload {
      attributes = var.attributes
    }
  }

  tags = var.tags
}

# Add to parent group if specified
resource "aws_iot_thing_group_membership" "parent" {
  count = var.parent_group_name != "" ? 1 : 0

  thing_group_name        = aws_iot_thing_group.this.name
  override_dynamic_groups = true

  # Parent must exist - use depends_on in caller
  thing_group_parent_name = var.parent_group_name
}

output "thing_group_name" {
  value = aws_iot_thing_group.this.name
}

output "thing_group_arn" {
  value = aws_iot_thing_group.this.arn
}

output "thing_group_id" {
  value = aws_iot_thing_group.this.id
}
```

**Variables File**:
```hcl
# _module/aws/iot/thing_group/variables.tf
variable "thing_group_name" {
  description = "Name of the Thing Group"
  type        = string
}

variable "parent_group_name" {
  description = "Parent Thing Group name"
  type        = string
  default     = ""
}

variable "description" {
  type    = string
  default = ""
}

variable "attributes" {
  type    = map(string)
  default = {}
}

variable "tags" {
  type    = map(string)
  default = {}
}
```

**Outputs File**:
```hcl
# _module/aws/iot/thing_group/outputs.tf
output "thing_group_name" {
  value = aws_iot_thing_group.this.name
}

output "thing_group_arn" {
  value = aws_iot_thing_group.this.arn
}
```

---

### Task 2.2: IoT Core Setup - Thing Groups Hierarchy
**File**: `dev/2.iot_core/main.tf`

**Purpose**: Create Vietnam → Regions → Sites hierarchy

**Implementation**:
```hcl
# dev/2.iot_core/main.tf
terraform {
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
    }
  }
}

# Root Thing Group: Vietnam
module "vietnam_thing_group" {
  source = "../../_module/aws/iot/thing_group"

  thing_group_name = "Vietnam"
  description      = "Root Thing Group for all Vietnam sites"

  attributes = {
    country = "Vietnam"
    total_sites = "20"
  }

  tags = local.tags
}

# Regional Thing Groups
module "northern_region_thing_group" {
  source = "../../_module/aws/iot/thing_group"

  thing_group_name   = "Northern-Region"
  parent_group_name  = module.vietnam_thing_group.thing_group_name
  description        = "Northern Region (Hanoi, Hai Phong)"

  attributes = {
    region = "northern"
  }

  tags = local.tags

  depends_on = [module.vietnam_thing_group]
}

module "central_region_thing_group" {
  source = "../../_module/aws/iot/thing_group"

  thing_group_name   = "Central-Region"
  parent_group_name  = module.vietnam_thing_group.thing_group_name
  description        = "Central Region (Da Nang, Hue)"

  attributes = {
    region = "central"
  }

  tags = local.tags

  depends_on = [module.vietnam_thing_group]
}

module "southern_region_thing_group" {
  source = "../../_module/aws/iot/thing_group"

  thing_group_name   = "Southern-Region"
  parent_group_name  = module.vietnam_thing_group.thing_group_name
  description        = "Southern Region (HCMC, Can Tho)"

  attributes = {
    region = "southern"
  }

  tags = local.tags

  depends_on = [module.vietnam_thing_group]
}

# Site Thing Groups (Pilot Site)
module "hanoi_site_001_thing_group" {
  source = "../../_module/aws/iot/thing_group"

  thing_group_name   = "Hanoi-Site-001"
  parent_group_name  = module.northern_region_thing_group.thing_group_name
  description        = "Hanoi Pilot Site - 15,000 cameras"

  attributes = {
    site_id       = "site-001"
    city          = "Hanoi"
    camera_count  = "15000"
    status        = "pilot"
  }

  tags = merge(local.tags, {
    SiteId = "site-001"
    Phase  = "Pilot"
  })

  depends_on = [module.northern_region_thing_group]
}

# Additional site groups for future (commented for now)
# module "hanoi_site_002_thing_group" { ... }
# module "hcmc_site_001_thing_group" { ... }
```

**Locals File**:
```hcl
# dev/2.iot_core/locals.tf
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

  # MQTT topic structure
  mqtt_topics = {
    incidents = "cameras/+/incidents"
    registry  = "cameras/+/registry"
    metrics   = "cameras/+/metrics"
  }
}
```

**Provider File**:
```hcl
# dev/2.iot_core/provider.tf
provider "aws" {
  region = "ap-southeast-1"

  default_tags {
    tags = local.tags
  }
}
```

---

### Task 2.3: IoT Policies Module
**File**: `_module/aws/iot/iot_policy/main.tf`

**Purpose**: Define permissions for Greengrass cores

**Module Code**:
```hcl
# _module/aws/iot/iot_policy/main.tf
variable "policy_name" {
  description = "Name of the IoT Policy"
  type        = string
}

variable "policy_document" {
  description = "IoT Policy document in JSON"
  type        = string
}

variable "tags" {
  type    = map(string)
  default = {}
}

resource "aws_iot_policy" "this" {
  name   = var.policy_name
  policy = var.policy_document

  tags = var.tags
}

output "policy_name" {
  value = aws_iot_policy.this.name
}

output "policy_arn" {
  value = aws_iot_policy.this.arn
}
```

---

### Task 2.4: IoT Policies Definition
**File**: `dev/2.iot_core/iot_policies.tf`

**Purpose**: Define specific policies for different device types

**Implementation**:
```hcl
# dev/2.iot_core/iot_policies.tf

# Policy for Greengrass Core devices
module "greengrass_core_policy" {
  source = "../../_module/aws/iot/iot_policy"

  policy_name = "${local.product_name}-${local.environment}-greengrass-core-policy"

  policy_document = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Action = [
          "iot:Connect"
        ]
        Resource = [
          "arn:aws:iot:${local.region}:${data.aws_caller_identity.current.account_id}:client/SmartHUB-*"
        ]
      },
      {
        Effect = "Allow"
        Action = [
          "iot:Publish",
          "iot:Receive"
        ]
        Resource = [
          "arn:aws:iot:${local.region}:${data.aws_caller_identity.current.account_id}:topic/cameras/*/incidents",
          "arn:aws:iot:${local.region}:${data.aws_caller_identity.current.account_id}:topic/cameras/*/registry",
          "arn:aws:iot:${local.region}:${data.aws_caller_identity.current.account_id}:topic/cameras/*/metrics",
          "arn:aws:iot:${local.region}:${data.aws_caller_identity.current.account_id}:topic/$aws/things/SmartHUB-*/shadow/*"
        ]
      },
      {
        Effect = "Allow"
        Action = [
          "iot:Subscribe"
        ]
        Resource = [
          "arn:aws:iot:${local.region}:${data.aws_caller_identity.current.account_id}:topicfilter/cameras/*/incidents",
          "arn:aws:iot:${local.region}:${data.aws_caller_identity.current.account_id}:topicfilter/$aws/things/SmartHUB-*/shadow/*"
        ]
      },
      {
        Effect = "Allow"
        Action = [
          "iot:UpdateThingShadow",
          "iot:GetThingShadow",
          "iot:DeleteThingShadow"
        ]
        Resource = [
          "arn:aws:iot:${local.region}:${data.aws_caller_identity.current.account_id}:thing/SmartHUB-*"
        ]
      },
      {
        Effect = "Allow"
        Action = [
          "greengrass:*"
        ]
        Resource = "*"
      }
    ]
  })

  tags = local.tags
}

# Restrictive policy for read-only access (future use)
module "iot_readonly_policy" {
  source = "../../_module/aws/iot/iot_policy"

  policy_name = "${local.product_name}-${local.environment}-iot-readonly-policy"

  policy_document = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Action = [
          "iot:Connect"
        ]
        Resource = "arn:aws:iot:${local.region}:${data.aws_caller_identity.current.account_id}:client/$${iot:Connection.Thing.ThingName}"
      },
      {
        Effect = "Allow"
        Action = [
          "iot:Subscribe"
        ]
        Resource = [
          "arn:aws:iot:${local.region}:${data.aws_caller_identity.current.account_id}:topicfilter/cameras/*/incidents"
        ]
      },
      {
        Effect = "Allow"
        Action = [
          "iot:Receive"
        ]
        Resource = [
          "arn:aws:iot:${local.region}:${data.aws_caller_identity.current.account_id}:topic/cameras/*/incidents"
        ]
      }
    ]
  })

  tags = local.tags
}

# Output policy ARNs
output "greengrass_core_policy_arn" {
  value = module.greengrass_core_policy.policy_arn
}

output "iot_readonly_policy_arn" {
  value = module.iot_readonly_policy.policy_arn
}
```

---

### Task 2.5: Certificate Management Setup
**File**: `dev/2.iot_core/certificates.tf`

**Purpose**: Setup for X.509 certificate management

**Note**: Certificates are typically generated during device provisioning, not in Terraform.
This file documents the process and creates necessary resources.

```hcl
# dev/2.iot_core/certificates.tf

# Note: Actual certificates should be created via AWS CLI or SDK during device onboarding
# This file creates supporting infrastructure

# S3 bucket for storing certificate metadata (optional)
resource "aws_s3_bucket" "iot_certificates" {
  bucket = "${local.product_name}-${local.environment}-iot-certificates"

  tags = merge(local.tags, {
    Purpose = "IoT Certificate Metadata Storage"
  })
}

resource "aws_s3_bucket_versioning" "iot_certificates" {
  bucket = aws_s3_bucket.iot_certificates.id

  versioning_configuration {
    status = "Enabled"
  }
}

resource "aws_s3_bucket_server_side_encryption_configuration" "iot_certificates" {
  bucket = aws_s3_bucket.iot_certificates.id

  rule {
    apply_server_side_encryption_by_default {
      sse_algorithm = "AES256"
    }
  }
}

resource "aws_s3_bucket_public_access_block" "iot_certificates" {
  bucket = aws_s3_bucket.iot_certificates.id

  block_public_acls       = true
  block_public_policy     = true
  ignore_public_acls      = true
  restrict_public_buckets = true
}

# DynamoDB table for certificate tracking
resource "aws_dynamodb_table" "certificate_registry" {
  name           = "${local.product_name}-${local.environment}-certificate-registry"
  billing_mode   = "PAY_PER_REQUEST"
  hash_key       = "certificate_id"
  range_key      = "thing_name"

  attribute {
    name = "certificate_id"
    type = "S"
  }

  attribute {
    name = "thing_name"
    type = "S"
  }

  attribute {
    name = "site_id"
    type = "S"
  }

  attribute {
    name = "status"
    type = "S"
  }

  global_secondary_index {
    name            = "site_id-index"
    hash_key        = "site_id"
    projection_type = "ALL"
  }

  global_secondary_index {
    name            = "status-index"
    hash_key        = "status"
    projection_type = "ALL"
  }

  ttl {
    attribute_name = "ttl"
    enabled        = true
  }

  tags = merge(local.tags, {
    Purpose = "Track IoT Certificates"
  })
}

# Output
output "certificate_bucket_name" {
  value = aws_s3_bucket.iot_certificates.id
}

output "certificate_registry_table_name" {
  value = aws_dynamodb_table.certificate_registry.name
}
```

**Certificate Creation Script** (to be used during deployment):
```bash
# scripts/create-iot-certificate.sh
#!/bin/bash
set -e

SITE_ID=$1
THING_NAME="SmartHUB-${SITE_ID}"
REGION="ap-southeast-1"

echo "Creating certificate for ${THING_NAME}..."

# Create certificate
CERT_ARN=$(aws iot create-keys-and-certificate \
  --set-as-active \
  --region ${REGION} \
  --query 'certificateArn' \
  --output text)

# Save certificate details
CERT_ID=$(aws iot describe-certificate \
  --certificate-arn ${CERT_ARN} \
  --region ${REGION} \
  --query 'certificateDescription.certificateId' \
  --output text)

echo "Certificate created: ${CERT_ID}"
echo "Certificate ARN: ${CERT_ARN}"

# Attach policy
aws iot attach-policy \
  --policy-name "aismc-dev-greengrass-core-policy" \
  --target ${CERT_ARN} \
  --region ${REGION}

echo "Policy attached to certificate"

# Output for use in Thing creation
echo "CERT_ARN=${CERT_ARN}"
echo "CERT_ID=${CERT_ID}"
```

---

### Task 2.6: Add Data Sources
**File**: `dev/2.iot_core/data.tf`

```hcl
# dev/2.iot_core/data.tf
data "aws_caller_identity" "current" {}

data "aws_region" "current" {}

data "aws_iot_endpoint" "data" {
  endpoint_type = "iot:Data-ATS"
}

data "aws_iot_endpoint" "credentials" {
  endpoint_type = "iot:CredentialProvider"
}

output "iot_data_endpoint" {
  value = data.aws_iot_endpoint.data.endpoint_address
}

output "iot_credentials_endpoint" {
  value = data.aws_iot_endpoint.credentials.endpoint_address
}
```

---

### Task 2.7: IoT Core Outputs
**File**: `dev/2.iot_core/outputs.tf`

```hcl
# dev/2.iot_core/outputs.tf

# Thing Groups
output "vietnam_thing_group_arn" {
  description = "ARN of Vietnam root Thing Group"
  value       = module.vietnam_thing_group.thing_group_arn
}

output "hanoi_site_001_thing_group_arn" {
  description = "ARN of Hanoi Site 001 Thing Group"
  value       = module.hanoi_site_001_thing_group.thing_group_arn
}

# IoT Policies
output "greengrass_core_policy_name" {
  description = "Name of Greengrass Core IoT Policy"
  value       = module.greengrass_core_policy.policy_name
}

# IoT Endpoints
output "iot_data_endpoint" {
  description = "IoT Core Data Endpoint"
  value       = data.aws_iot_endpoint.data.endpoint_address
}

output "iot_credentials_endpoint" {
  description = "IoT Core Credentials Endpoint"
  value       = data.aws_iot_endpoint.credentials.endpoint_address
}

# Certificate Infrastructure
output "certificate_bucket_name" {
  description = "S3 bucket for certificate metadata"
  value       = aws_s3_bucket.iot_certificates.id
}

output "certificate_registry_table_name" {
  description = "DynamoDB table for certificate tracking"
  value       = aws_dynamodb_table.certificate_registry.name
}

# MQTT Topics
output "mqtt_topics" {
  description = "MQTT topic structure"
  value       = local.mqtt_topics
}
```

---

## **DAY 6-7: DATA LAYER**

### Task 3.1: DynamoDB Module
**File**: `_module/aws/data/dynamodb/main.tf`

```hcl
# _module/aws/data/dynamodb/main.tf
variable "table_name" {
  description = "DynamoDB table name"
  type        = string
}

variable "billing_mode" {
  description = "DynamoDB billing mode"
  type        = string
  default     = "PAY_PER_REQUEST"
}

variable "hash_key" {
  description = "Hash key attribute name"
  type        = string
}

variable "range_key" {
  description = "Range key attribute name (optional)"
  type        = string
  default     = ""
}

variable "attributes" {
  description = "List of attribute definitions"
  type = list(object({
    name = string
    type = string
  }))
}

variable "global_secondary_indexes" {
  description = "List of global secondary indexes"
  type = list(object({
    name            = string
    hash_key        = string
    range_key       = string
    projection_type = string
  }))
  default = []
}

variable "ttl_attribute_name" {
  description = "TTL attribute name"
  type        = string
  default     = ""
}

variable "point_in_time_recovery" {
  description = "Enable point-in-time recovery"
  type        = bool
  default     = true
}

variable "tags" {
  type    = map(string)
  default = {}
}

resource "aws_dynamodb_table" "this" {
  name         = var.table_name
  billing_mode = var.billing_mode
  hash_key     = var.hash_key
  range_key    = var.range_key != "" ? var.range_key : null

  dynamic "attribute" {
    for_each = var.attributes
    content {
      name = attribute.value.name
      type = attribute.value.type
    }
  }

  dynamic "global_secondary_index" {
    for_each = var.global_secondary_indexes
    content {
      name            = global_secondary_index.value.name
      hash_key        = global_secondary_index.value.hash_key
      range_key       = global_secondary_index.value.range_key
      projection_type = global_secondary_index.value.projection_type
    }
  }

  dynamic "ttl" {
    for_each = var.ttl_attribute_name != "" ? [1] : []
    content {
      attribute_name = var.ttl_attribute_name
      enabled        = true
    }
  }

  point_in_time_recovery {
    enabled = var.point_in_time_recovery
  }

  tags = var.tags
}

output "table_name" {
  value = aws_dynamodb_table.this.name
}

output "table_arn" {
  value = aws_dynamodb_table.this.arn
}

output "table_id" {
  value = aws_dynamodb_table.this.id
}
```

---

### Task 3.2: DynamoDB Tables
**File**: `dev/3.data_layer/dynamodb.tf`

```hcl
# dev/3.data_layer/dynamodb.tf

# DeviceRegistry Table
module "device_registry_table" {
  source = "../../_module/aws/data/dynamodb"

  table_name   = "${local.product_name}-${local.environment}-device-registry"
  billing_mode = "PAY_PER_REQUEST"
  hash_key     = "entity_id"

  attributes = [
    {
      name = "entity_id"
      type = "S"
    },
    {
      name = "site_id"
      type = "S"
    },
    {
      name = "device_type"
      type = "S"
    }
  ]

  global_secondary_indexes = [
    {
      name            = "site_id-index"
      hash_key        = "site_id"
      range_key       = ""
      projection_type = "ALL"
    },
    {
      name            = "device_type-index"
      hash_key        = "device_type"
      range_key       = ""
      projection_type = "ALL"
    }
  ]

  point_in_time_recovery = true

  tags = merge(local.tags, {
    Purpose = "Camera Device Registry"
  })
}

# CameraIncidents Table
module "camera_incidents_table" {
  source = "../../_module/aws/data/dynamodb"

  table_name   = "${local.product_name}-${local.environment}-camera-incidents"
  billing_mode = "PAY_PER_REQUEST"
  hash_key     = "incident_id"
  range_key    = "timestamp"

  attributes = [
    {
      name = "incident_id"
      type = "S"
    },
    {
      name = "timestamp"
      type = "S"
    },
    {
      name = "site_id"
      type = "S"
    },
    {
      name = "entity_id"
      type = "S"
    },
    {
      name = "incident_type"
      type = "S"
    },
    {
      name = "status"
      type = "S"
    }
  ]

  global_secondary_indexes = [
    {
      name            = "site_id-timestamp-index"
      hash_key        = "site_id"
      range_key       = "timestamp"
      projection_type = "ALL"
    },
    {
      name            = "entity_id-timestamp-index"
      hash_key        = "entity_id"
      range_key       = "timestamp"
      projection_type = "ALL"
    },
    {
      name            = "incident_type-timestamp-index"
      hash_key        = "incident_type"
      range_key       = "timestamp"
      projection_type = "ALL"
    },
    {
      name            = "status-timestamp-index"
      hash_key        = "status"
      range_key       = "timestamp"
      projection_type = "ALL"
    }
  ]

  ttl_attribute_name     = "ttl"
  point_in_time_recovery = true

  tags = merge(local.tags, {
    Purpose = "Camera Incident Tracking"
  })
}

# Outputs
output "device_registry_table_name" {
  value = module.device_registry_table.table_name
}

output "device_registry_table_arn" {
  value = module.device_registry_table.table_arn
}

output "camera_incidents_table_name" {
  value = module.camera_incidents_table.table_name
}

output "camera_incidents_table_arn" {
  value = module.camera_incidents_table.table_arn
}
```

---

### Task 3.3: Timestream Database
**File**: `dev/3.data_layer/timestream.tf`

```hcl
# dev/3.data_layer/timestream.tf

# Timestream Database
resource "aws_timestreamwrite_database" "iot_metrics" {
  database_name = "${local.product_name}-${local.environment}-iot-metrics"

  tags = merge(local.tags, {
    Purpose = "IoT Time-Series Metrics"
  })
}

# Timestream Table for Camera Metrics
resource "aws_timestreamwrite_table" "camera_metrics" {
  database_name = aws_timestreamwrite_database.iot_metrics.database_name
  table_name    = "camera-metrics"

  retention_properties {
    memory_store_retention_period_in_hours  = 24    # 24 hours in memory
    magnetic_store_retention_period_in_days = 365   # 1 year in magnetic
  }

  magnetic_store_write_properties {
    enable_magnetic_store_writes = true
  }

  tags = merge(local.tags, {
    MetricType = "Camera"
  })
}

# Timestream Table for Site Metrics
resource "aws_timestreamwrite_table" "site_metrics" {
  database_name = aws_timestreamwrite_database.iot_metrics.database_name
  table_name    = "site-metrics"

  retention_properties {
    memory_store_retention_period_in_hours  = 24
    magnetic_store_retention_period_in_days = 365
  }

  magnetic_store_write_properties {
    enable_magnetic_store_writes = true
  }

  tags = merge(local.tags, {
    MetricType = "Site"
  })
}

# Timestream Table for System Metrics
resource "aws_timestreamwrite_table" "system_metrics" {
  database_name = aws_timestreamwrite_database.iot_metrics.database_name
  table_name    = "system-metrics"

  retention_properties {
    memory_store_retention_period_in_hours  = 168  # 7 days in memory
    magnetic_store_retention_period_in_days = 730  # 2 years in magnetic
  }

  magnetic_store_write_properties {
    enable_magnetic_store_writes = true
  }

  tags = merge(local.tags, {
    MetricType = "System"
  })
}

# Outputs
output "timestream_database_name" {
  value = aws_timestreamwrite_database.iot_metrics.database_name
}

output "timestream_database_arn" {
  value = aws_timestreamwrite_database.iot_metrics.arn
}

output "camera_metrics_table_name" {
  value = aws_timestreamwrite_table.camera_metrics.table_name
}

output "site_metrics_table_name" {
  value = aws_timestreamwrite_table.site_metrics.table_name
}

output "system_metrics_table_name" {
  value = aws_timestreamwrite_table.system_metrics.table_name
}
```

---

### Task 3.4: Data Layer Configuration Files
**File**: `dev/3.data_layer/locals.tf`

```hcl
# dev/3.data_layer/locals.tf
locals {
  product_name = "aismc"
  environment  = "dev"

  tags = {
    Environment = local.environment
    Product     = local.product_name
    ManagedBy   = "Terraform"
    Project     = "AIOps-IoC"
    Layer       = "Data"
  }
}
```

**File**: `dev/3.data_layer/provider.tf`

```hcl
# dev/3.data_layer/provider.tf
provider "aws" {
  region = "ap-southeast-1"

  default_tags {
    tags = local.tags
  }
}
```

**File**: `dev/3.data_layer/outputs.tf`

```hcl
# dev/3.data_layer/outputs.tf

# DynamoDB Tables
output "device_registry_table_name" {
  description = "Device Registry DynamoDB table name"
  value       = module.device_registry_table.table_name
}

output "camera_incidents_table_name" {
  description = "Camera Incidents DynamoDB table name"
  value       = module.camera_incidents_table.table_name
}

# Timestream
output "timestream_database_name" {
  description = "Timestream database name"
  value       = aws_timestreamwrite_database.iot_metrics.database_name
}

output "timestream_tables" {
  description = "Timestream table names"
  value = {
    camera_metrics = aws_timestreamwrite_table.camera_metrics.table_name
    site_metrics   = aws_timestreamwrite_table.site_metrics.table_name
    system_metrics = aws_timestreamwrite_table.system_metrics.table_name
  }
}
```

---

## **DAY 8-9: INTEGRATION LAYER**

### Task 4.1: IoT Rules Engine
**File**: `dev/4.iot_rules/main.tf`

```hcl
# dev/4.iot_rules/main.tf

# Data sources
data "terraform_remote_state" "iam" {
  backend = "s3"
  config = {
    bucket = "aismc-nonprod-terraform-state"
    key    = "dev/iam/terraform.tfstate"
    region = "ap-southeast-1"
  }
}

data "terraform_remote_state" "data_layer" {
  backend = "s3"
  config = {
    bucket = "aismc-nonprod-terraform-state"
    key    = "dev/data-layer/terraform.tfstate"
    region = "ap-southeast-1"
  }
}

# Rule: Route Incidents to DynamoDB
resource "aws_iot_topic_rule" "incidents_to_dynamodb" {
  name        = "${local.product_name}_${local.environment}_incidents_to_dynamodb"
  description = "Route camera incidents to DynamoDB CameraIncidents table"
  enabled     = true
  sql         = "SELECT * FROM 'cameras/+/incidents'"
  sql_version = "2016-03-23"

  dynamodb_v2 {
    role_arn = data.terraform_remote_state.iam.outputs.iot_core_service_role_arn

    put_item {
      table_name = data.terraform_remote_state.data_layer.outputs.camera_incidents_table_name
    }
  }

  error_action {
    cloudwatch_logs {
      log_group_name = aws_cloudwatch_log_group.iot_rules_errors.name
      role_arn       = data.terraform_remote_state.iam.outputs.iot_core_service_role_arn
    }
  }
}

# Rule: Route Registry Updates to DynamoDB
resource "aws_iot_topic_rule" "registry_to_dynamodb" {
  name        = "${local.product_name}_${local.environment}_registry_to_dynamodb"
  description = "Route camera registry updates to DynamoDB DeviceRegistry table"
  enabled     = true
  sql         = "SELECT * FROM 'cameras/+/registry'"
  sql_version = "2016-03-23"

  dynamodb_v2 {
    role_arn = data.terraform_remote_state.iam.outputs.iot_core_service_role_arn

    put_item {
      table_name = data.terraform_remote_state.data_layer.outputs.device_registry_table_name
    }
  }

  error_action {
    cloudwatch_logs {
      log_group_name = aws_cloudwatch_log_group.iot_rules_errors.name
      role_arn       = data.terraform_remote_state.iam.outputs.iot_core_service_role_arn
    }
  }
}

# Rule: Critical Alerts to SNS
resource "aws_iot_topic_rule" "critical_alerts_to_sns" {
  name        = "${local.product_name}_${local.environment}_critical_alerts"
  description = "Send critical alerts to SNS topic"
  enabled     = true
  sql         = "SELECT * FROM 'cameras/+/incidents' WHERE incident_type = 'camera_offline' AND priority = 'critical'"
  sql_version = "2016-03-23"

  sns {
    role_arn   = data.terraform_remote_state.iam.outputs.iot_core_service_role_arn
    target_arn = aws_sns_topic.critical_alerts.arn
    message_format = "JSON"
  }

  error_action {
    cloudwatch_logs {
      log_group_name = aws_cloudwatch_log_group.iot_rules_errors.name
      role_arn       = data.terraform_remote_state.iam.outputs.iot_core_service_role_arn
    }
  }
}

# Rule: Metrics to Timestream
resource "aws_iot_topic_rule" "metrics_to_timestream" {
  name        = "${local.product_name}_${local.environment}_metrics_to_timestream"
  description = "Route camera metrics to Timestream database"
  enabled     = true
  sql         = "SELECT * FROM 'cameras/+/metrics'"
  sql_version = "2016-03-23"

  timestream {
    role_arn      = data.terraform_remote_state.iam.outputs.iot_core_service_role_arn
    database_name = data.terraform_remote_state.data_layer.outputs.timestream_database_name
    table_name    = data.terraform_remote_state.data_layer.outputs.timestream_tables["camera_metrics"]

    dimension {
      name  = "site_id"
      value = "${site_id}"
    }

    dimension {
      name  = "entity_id"
      value = "${entity_id}"
    }
  }

  error_action {
    cloudwatch_logs {
      log_group_name = aws_cloudwatch_log_group.iot_rules_errors.name
      role_arn       = data.terraform_remote_state.iam.outputs.iot_core_service_role_arn
    }
  }
}

# CloudWatch Log Group for rule errors
resource "aws_cloudwatch_log_group" "iot_rules_errors" {
  name              = "/aws/iot/rules/${local.product_name}-${local.environment}/errors"
  retention_in_days = 30

  tags = local.tags
}
```

---

### Task 4.2: SNS Topics for Alerting
**File**: `dev/4.iot_rules/sns.tf`

```hcl
# dev/4.iot_rules/sns.tf

# SNS Topic for Critical Alerts
resource "aws_sns_topic" "critical_alerts" {
  name         = "${local.product_name}-${local.environment}-critical-alerts"
  display_name = "AIOps IoC Critical Alerts"

  tags = merge(local.tags, {
    AlertLevel = "Critical"
  })
}

# SNS Topic for Warning Alerts
resource "aws_sns_topic" "warning_alerts" {
  name         = "${local.product_name}-${local.environment}-warning-alerts"
  display_name = "AIOps IoC Warning Alerts"

  tags = merge(local.tags, {
    AlertLevel = "Warning"
  })
}

# SNS Topic for Operational Notifications
resource "aws_sns_topic" "operational_notifications" {
  name         = "${local.product_name}-${local.environment}-operational-notifications"
  display_name = "AIOps IoC Operational Notifications"

  tags = merge(local.tags, {
    AlertLevel = "Info"
  })
}

# Email subscription for critical alerts (to be confirmed manually)
resource "aws_sns_topic_subscription" "critical_email" {
  topic_arn = aws_sns_topic.critical_alerts.arn
  protocol  = "email"
  endpoint  = var.alert_email
}

# Outputs
output "critical_alerts_topic_arn" {
  value = aws_sns_topic.critical_alerts.arn
}

output "warning_alerts_topic_arn" {
  value = aws_sns_topic.warning_alerts.arn
}

output "operational_notifications_topic_arn" {
  value = aws_sns_topic.operational_notifications.arn
}
```

**File**: `dev/4.iot_rules/variables.tf`

```hcl
# dev/4.iot_rules/variables.tf
variable "alert_email" {
  description = "Email address for critical alerts"
  type        = string
  default     = "aiops-alerts@aismc.vn"
}
```

---

### Task 4.3: IoT Rules Configuration Files
**File**: `dev/4.iot_rules/locals.tf`

```hcl
# dev/4.iot_rules/locals.tf
locals {
  product_name = "aismc"
  environment  = "dev"

  tags = {
    Environment = local.environment
    Product     = local.product_name
    ManagedBy   = "Terraform"
    Project     = "AIOps-IoC"
    Layer       = "Integration"
  }
}
```

**File**: `dev/4.iot_rules/provider.tf`

```hcl
# dev/4.iot_rules/provider.tf
provider "aws" {
  region = "ap-southeast-1"

  default_tags {
    tags = local.tags
  }
}
```

**File**: `dev/4.iot_rules/outputs.tf`

```hcl
# dev/4.iot_rules/outputs.tf

output "iot_rules" {
  description = "IoT Rule names and ARNs"
  value = {
    incidents_to_dynamodb    = aws_iot_topic_rule.incidents_to_dynamodb.arn
    registry_to_dynamodb     = aws_iot_topic_rule.registry_to_dynamodb.arn
    critical_alerts_to_sns   = aws_iot_topic_rule.critical_alerts_to_sns.arn
    metrics_to_timestream    = aws_iot_topic_rule.metrics_to_timestream.arn
  }
}

output "sns_topics" {
  description = "SNS topic ARNs"
  value = {
    critical_alerts            = aws_sns_topic.critical_alerts.arn
    warning_alerts             = aws_sns_topic.warning_alerts.arn
    operational_notifications  = aws_sns_topic.operational_notifications.arn
  }
}
```

---

## **DAY 10: API GATEWAY & VALIDATION**

### Task 5.1: API Gateway Skeleton
**File**: `dev/5.api_gateway/main.tf`

```hcl
# dev/5.api_gateway/main.tf

# REST API Gateway
resource "aws_api_gateway_rest_api" "aiops_api" {
  name        = "${local.product_name}-${local.environment}-aiops-api"
  description = "AIOps IoC REST API"

  endpoint_configuration {
    types = ["REGIONAL"]
  }

  tags = local.tags
}

# API Resources
resource "aws_api_gateway_resource" "cameras" {
  rest_api_id = aws_api_gateway_rest_api.aiops_api.id
  parent_id   = aws_api_gateway_rest_api.aiops_api.root_resource_id
  path_part   = "cameras"
}

resource "aws_api_gateway_resource" "incidents" {
  rest_api_id = aws_api_gateway_rest_api.aiops_api.id
  parent_id   = aws_api_gateway_rest_api.aiops_api.root_resource_id
  path_part   = "incidents"
}

resource "aws_api_gateway_resource" "metrics" {
  rest_api_id = aws_api_gateway_rest_api.aiops_api.id
  parent_id   = aws_api_gateway_rest_api.aiops_api.root_resource_id
  path_part   = "metrics"
}

# GET /cameras method
resource "aws_api_gateway_method" "get_cameras" {
  rest_api_id   = aws_api_gateway_rest_api.aiops_api.id
  resource_id   = aws_api_gateway_resource.cameras.id
  http_method   = "GET"
  authorization = "NONE"  # Add auth later
}

# Lambda integration for GET /cameras
resource "aws_api_gateway_integration" "get_cameras_lambda" {
  rest_api_id             = aws_api_gateway_rest_api.aiops_api.id
  resource_id             = aws_api_gateway_resource.cameras.id
  http_method             = aws_api_gateway_method.get_cameras.http_method
  integration_http_method = "POST"
  type                    = "AWS_PROXY"
  uri                     = aws_lambda_function.get_cameras.invoke_arn
}

# API Deployment
resource "aws_api_gateway_deployment" "api_deployment" {
  rest_api_id = aws_api_gateway_rest_api.aiops_api.id

  depends_on = [
    aws_api_gateway_integration.get_cameras_lambda
  ]

  lifecycle {
    create_before_destroy = true
  }
}

# API Stage
resource "aws_api_gateway_stage" "dev" {
  deployment_id = aws_api_gateway_deployment.api_deployment.id
  rest_api_id   = aws_api_gateway_rest_api.aiops_api.id
  stage_name    = "dev"

  tags = local.tags
}

# Enable API Gateway logging
resource "aws_api_gateway_method_settings" "all" {
  rest_api_id = aws_api_gateway_rest_api.aiops_api.id
  stage_name  = aws_api_gateway_stage.dev.stage_name
  method_path = "*/*"

  settings {
    metrics_enabled = true
    logging_level   = "INFO"
  }
}

# CloudWatch Log Group for API Gateway
resource "aws_cloudwatch_log_group" "api_gateway_logs" {
  name              = "/aws/apigateway/${local.product_name}-${local.environment}"
  retention_in_days = 30

  tags = local.tags
}
```

---

### Task 5.2: Lambda Functions Skeleton
**File**: `dev/5.api_gateway/lambda.tf`

```hcl
# dev/5.api_gateway/lambda.tf

data "terraform_remote_state" "data_layer" {
  backend = "s3"
  config = {
    bucket = "aismc-nonprod-terraform-state"
    key    = "dev/data-layer/terraform.tfstate"
    region = "ap-southeast-1"
  }
}

data "terraform_remote_state" "iam" {
  backend = "s3"
  config = {
    bucket = "aismc-nonprod-terraform-state"
    key    = "dev/iam/terraform.tfstate"
    region = "ap-southeast-1"
  }
}

# Lambda function: GET /cameras
resource "aws_lambda_function" "get_cameras" {
  filename      = "lambda/get_cameras.zip"
  function_name = "${local.product_name}-${local.environment}-get-cameras"
  role          = data.terraform_remote_state.iam.outputs.iot_lambda_role_arn
  handler       = "index.handler"
  runtime       = "python3.11"
  timeout       = 30
  memory_size   = 256

  environment {
    variables = {
      DEVICE_REGISTRY_TABLE = data.terraform_remote_state.data_layer.outputs.device_registry_table_name
      REGION                = "ap-southeast-1"
    }
  }

  tags = local.tags
}

# Lambda permission for API Gateway
resource "aws_lambda_permission" "apigw_get_cameras" {
  statement_id  = "AllowAPIGatewayInvoke"
  action        = "lambda:InvokeFunction"
  function_name = aws_lambda_function.get_cameras.function_name
  principal     = "apigateway.amazonaws.com"
  source_arn    = "${aws_api_gateway_rest_api.aiops_api.execution_arn}/*/*"
}

# Lambda function: GET /incidents
resource "aws_lambda_function" "get_incidents" {
  filename      = "lambda/get_incidents.zip"
  function_name = "${local.product_name}-${local.environment}-get-incidents"
  role          = data.terraform_remote_state.iam.outputs.iot_lambda_role_arn
  handler       = "index.handler"
  runtime       = "python3.11"
  timeout       = 30
  memory_size   = 256

  environment {
    variables = {
      INCIDENTS_TABLE = data.terraform_remote_state.data_layer.outputs.camera_incidents_table_name
      REGION          = "ap-southeast-1"
    }
  }

  tags = local.tags
}

# Lambda CloudWatch Log Groups
resource "aws_cloudwatch_log_group" "lambda_get_cameras_logs" {
  name              = "/aws/lambda/${aws_lambda_function.get_cameras.function_name}"
  retention_in_days = 30

  tags = local.tags
}

resource "aws_cloudwatch_log_group" "lambda_get_incidents_logs" {
  name              = "/aws/lambda/${aws_lambda_function.get_incidents.function_name}"
  retention_in_days = 30

  tags = local.tags
}
```

---

### Task 5.3: Lambda Function Code (Skeleton)
**File**: `dev/5.api_gateway/lambda/get_cameras/index.py`

```python
# dev/5.api_gateway/lambda/get_cameras/index.py
import json
import os
import boto3
from decimal import Decimal

dynamodb = boto3.resource('dynamodb', region_name=os.environ['REGION'])
table = dynamodb.Table(os.environ['DEVICE_REGISTRY_TABLE'])

class DecimalEncoder(json.JSONEncoder):
    def default(self, obj):
        if isinstance(obj, Decimal):
            return float(obj)
        return super(DecimalEncoder, self).default(obj)

def handler(event, context):
    """
    GET /cameras
    Query parameters:
    - site_id: Filter by site
    - limit: Number of results (default: 100)
    - last_key: For pagination
    """
    try:
        # Parse query parameters
        params = event.get('queryStringParameters', {}) or {}
        site_id = params.get('site_id')
        limit = int(params.get('limit', 100))
        last_key = params.get('last_key')

        # Build query
        scan_kwargs = {
            'Limit': limit
        }

        if last_key:
            scan_kwargs['ExclusiveStartKey'] = json.loads(last_key)

        # Query by site_id if provided
        if site_id:
            scan_kwargs['IndexName'] = 'site_id-index'
            scan_kwargs['KeyConditionExpression'] = 'site_id = :site_id'
            scan_kwargs['ExpressionAttributeValues'] = {':site_id': site_id}
            response = table.query(**scan_kwargs)
        else:
            response = table.scan(**scan_kwargs)

        # Prepare response
        result = {
            'cameras': response.get('Items', []),
            'count': response.get('Count', 0)
        }

        if 'LastEvaluatedKey' in response:
            result['last_key'] = json.dumps(response['LastEvaluatedKey'], cls=DecimalEncoder)

        return {
            'statusCode': 200,
            'headers': {
                'Content-Type': 'application/json',
                'Access-Control-Allow-Origin': '*'
            },
            'body': json.dumps(result, cls=DecimalEncoder)
        }

    except Exception as e:
        print(f"Error: {str(e)}")
        return {
            'statusCode': 500,
            'headers': {
                'Content-Type': 'application/json',
                'Access-Control-Allow-Origin': '*'
            },
            'body': json.dumps({'error': str(e)})
        }
```

**Build Script**:
```bash
# scripts/build-lambda.sh
#!/bin/bash
set -e

LAMBDA_NAME=$1
LAMBDA_DIR="dev/5.api_gateway/lambda/${LAMBDA_NAME}"

echo "Building Lambda function: ${LAMBDA_NAME}"

cd ${LAMBDA_DIR}

# Create deployment package
rm -f ${LAMBDA_NAME}.zip
zip -r ${LAMBDA_NAME}.zip index.py

echo "Lambda package created: ${LAMBDA_NAME}.zip"
```

---

### Task 5.4: API Gateway Configuration Files
**File**: `dev/5.api_gateway/locals.tf`

```hcl
# dev/5.api_gateway/locals.tf
locals {
  product_name = "aismc"
  environment  = "dev"

  tags = {
    Environment = local.environment
    Product     = local.product_name
    ManagedBy   = "Terraform"
    Project     = "AIOps-IoC"
    Layer       = "API"
  }
}
```

**File**: `dev/5.api_gateway/provider.tf`

```hcl
# dev/5.api_gateway/provider.tf
provider "aws" {
  region = "ap-southeast-1"

  default_tags {
    tags = local.tags
  }
}
```

**File**: `dev/5.api_gateway/outputs.tf`

```hcl
# dev/5.api_gateway/outputs.tf

output "api_gateway_id" {
  description = "API Gateway REST API ID"
  value       = aws_api_gateway_rest_api.aiops_api.id
}

output "api_gateway_endpoint" {
  description = "API Gateway endpoint URL"
  value       = "${aws_api_gateway_stage.dev.invoke_url}"
}

output "api_gateway_stage" {
  description = "API Gateway stage name"
  value       = aws_api_gateway_stage.dev.stage_name
}

output "lambda_functions" {
  description = "Lambda function ARNs"
  value = {
    get_cameras   = aws_lambda_function.get_cameras.arn
    get_incidents = aws_lambda_function.get_incidents.arn
  }
}
```

---

## 🔍 VALIDATION & TESTING

### Validation Checklist

**File**: `claudedocs/VALIDATION-CHECKLIST.md`

```markdown
# Week 1-2 Infrastructure Validation Checklist

## Day 1-2: Foundation

### AWS Organization
- [ ] Organization created
- [ ] Dev account provisioned
- [ ] SCPs applied
- [ ] Cost allocation tags configured

### IAM Roles
- [ ] IoT Core service role created
- [ ] Greengrass Core role created
- [ ] Lambda execution role created
- [ ] Cross-account assume role working

### Network
- [ ] VPC exists: `terraform -chdir=dev/1.networking output vpc_id`
- [ ] Subnets in 2 AZs
- [ ] NAT gateways operational
- [ ] Route tables correct

---

## Day 3-5: IoT Core

### Thing Groups
```bash
# Verify Thing Groups hierarchy
aws iot describe-thing-group --thing-group-name Vietnam
aws iot describe-thing-group --thing-group-name Northern-Region
aws iot describe-thing-group --thing-group-name Hanoi-Site-001

# Expected hierarchy:
# Vietnam → Northern-Region → Hanoi-Site-001
```

### IoT Policies
```bash
# List policies
aws iot list-policies

# Verify Greengrass Core policy
aws iot get-policy --policy-name aismc-dev-greengrass-core-policy

# Expected actions:
# - iot:Connect
# - iot:Publish
# - iot:Subscribe
# - iot:UpdateThingShadow
```

### IoT Endpoints
```bash
# Get IoT endpoints
terraform -chdir=dev/2.iot_core output iot_data_endpoint
terraform -chdir=dev/2.iot_core output iot_credentials_endpoint

# Test connectivity
aws iot describe-endpoint --endpoint-type iot:Data-ATS
```

---

## Day 6-7: Data Layer

### DynamoDB Tables
```bash
# Verify DeviceRegistry table
aws dynamodb describe-table \
  --table-name aismc-dev-device-registry

# Expected:
# - Hash key: entity_id
# - GSI: site_id-index, device_type-index
# - Point-in-time recovery: ENABLED

# Verify CameraIncidents table
aws dynamodb describe-table \
  --table-name aismc-dev-camera-incidents

# Expected:
# - Hash key: incident_id
# - Range key: timestamp
# - GSI: site_id-timestamp-index, entity_id-timestamp-index
# - TTL enabled on 'ttl' attribute
```

### Timestream Database
```bash
# Verify database
aws timestream-write describe-database \
  --database-name aismc-dev-iot-metrics

# Verify tables
aws timestream-write describe-table \
  --database-name aismc-dev-iot-metrics \
  --table-name camera-metrics

# Expected retention:
# - Memory: 24 hours
# - Magnetic: 365 days
```

---

## Day 8-9: Integration Layer

### IoT Rules
```bash
# List all rules
aws iot list-topic-rules

# Verify incidents rule
aws iot get-topic-rule \
  --rule-name aismc_dev_incidents_to_dynamodb

# Expected SQL:
# SELECT * FROM 'cameras/+/incidents'
```

### SNS Topics
```bash
# List SNS topics
aws sns list-topics

# Verify critical alerts topic
aws sns get-topic-attributes \
  --topic-arn arn:aws:sns:ap-southeast-1:ACCOUNT_ID:aismc-dev-critical-alerts
```

### Test IoT Rule
```bash
# Publish test message
aws iot-data publish \
  --topic cameras/site-001/incidents \
  --payload '{"incident_id":"test-001","site_id":"site-001","timestamp":"2025-12-29T10:00:00Z","incident_type":"camera_offline","entity_id":"camera-001"}' \
  --region ap-southeast-1

# Verify in DynamoDB
aws dynamodb get-item \
  --table-name aismc-dev-camera-incidents \
  --key '{"incident_id":{"S":"test-001"},"timestamp":{"S":"2025-12-29T10:00:00Z"}}'
```

---

## Day 10: API Gateway

### API Gateway
```bash
# Get API endpoint
terraform -chdir=dev/5.api_gateway output api_gateway_endpoint

# Test GET /cameras
curl -X GET "https://API_ID.execute-api.ap-southeast-1.amazonaws.com/dev/cameras?limit=10"

# Expected response:
# {
#   "cameras": [],
#   "count": 0
# }
```

### Lambda Functions
```bash
# List Lambda functions
aws lambda list-functions --query 'Functions[?starts_with(FunctionName, `aismc-dev`)].FunctionName'

# Test Lambda directly
aws lambda invoke \
  --function-name aismc-dev-get-cameras \
  --payload '{"queryStringParameters":{"limit":"10"}}' \
  response.json

cat response.json
```

---

## End-to-End Test

### Scenario: Device Registry Update
```bash
# 1. Publish device registry message
aws iot-data publish \
  --topic cameras/site-001/registry \
  --payload '{
    "@context": "https://uri.etsi.org/ngsi-ld/v1/ngsi-ld-core-context.jsonld",
    "id": "urn:ngsi-ld:Camera:camera-001",
    "type": "Camera",
    "entity_id": {"type": "Property", "value": "camera-001"},
    "site_id": {"type": "Property", "value": "site-001"},
    "device_type": {"type": "Property", "value": "IP_Camera"}
  }'

# 2. Verify in DynamoDB
aws dynamodb scan \
  --table-name aismc-dev-device-registry \
  --limit 10

# 3. Query via API
curl "https://API_ID.execute-api.ap-southeast-1.amazonaws.com/dev/cameras?site_id=site-001"
```

### Scenario: Incident Alert
```bash
# 1. Publish incident
aws iot-data publish \
  --topic cameras/site-001/incidents \
  --payload '{
    "incident_id": "inc-001",
    "site_id": "site-001",
    "entity_id": "camera-001",
    "incident_type": "camera_offline",
    "priority": "critical",
    "timestamp": "2025-12-29T10:00:00Z"
  }'

# 2. Check DynamoDB
aws dynamodb get-item \
  --table-name aismc-dev-camera-incidents \
  --key '{"incident_id":{"S":"inc-001"},"timestamp":{"S":"2025-12-29T10:00:00Z"}}'

# 3. Check SNS (email should be received)
```

---

## Cost Validation
```bash
# Enable Cost Explorer
aws ce get-cost-and-usage \
  --time-period Start=2025-12-01,End=2025-12-31 \
  --granularity MONTHLY \
  --metrics BlendedCost \
  --group-by Type=SERVICE

# Expected costs (Week 1-2):
# - IoT Core: ~$5 (no device messages yet)
# - DynamoDB: ~$2 (on-demand, minimal data)
# - Timestream: ~$1 (no data yet)
# - Lambda: Free tier
# - API Gateway: Free tier
# Total: < $10/month
```

---

## Security Validation
```bash
# Check IAM role policies (least privilege)
aws iam get-role-policy \
  --role-name aismc-dev-iot-core-service-role \
  --policy-name iot-dynamodb-access

# Verify S3 bucket public access blocked
aws s3api get-public-access-block \
  --bucket aismc-dev-iot-certificates

# Check DynamoDB encryption at rest
aws dynamodb describe-table \
  --table-name aismc-dev-device-registry \
  --query 'Table.SSEDescription'
```

---

## Cleanup (if needed)
```bash
# Destroy in reverse order
terraform -chdir=dev/5.api_gateway destroy
terraform -chdir=dev/4.iot_rules destroy
terraform -chdir=dev/3.data_layer destroy
terraform -chdir=dev/2.iot_core destroy
# Keep network and IAM
```
```

---

## 📦 DEPLOYMENT SCRIPTS

### Deployment Automation Script
**File**: `scripts/deploy-week1-2.sh`

```bash
#!/bin/bash
set -e

# Week 1-2 Infrastructure Deployment Script
# Usage: ./scripts/deploy-week1-2.sh

REGION="ap-southeast-1"
ENVIRONMENT="dev"
PRODUCT="aismc"

echo "=================================="
echo "Week 1-2 Infrastructure Deployment"
echo "=================================="
echo "Region: ${REGION}"
echo "Environment: ${ENVIRONMENT}"
echo "Product: ${PRODUCT}"
echo "=================================="

# Color codes
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
NC='\033[0m' # No Color

function log_info() {
    echo -e "${GREEN}[INFO]${NC} $1"
}

function log_warn() {
    echo -e "${YELLOW}[WARN]${NC} $1"
}

function log_error() {
    echo -e "${RED}[ERROR]${NC} $1"
}

# Step 0: Initialize S3 backend (if not exists)
log_info "Step 0: Initialize S3 backend for Terraform state"
cd ops/0.init_s3_backend
if ! terraform init; then
    log_error "Failed to initialize S3 backend"
    exit 1
fi
terraform apply -auto-approve
cd ../..

# Step 1: Deploy IAM roles
log_info "Step 1: Deploying IAM roles and policies"
cd dev/0.iam_assume_role_terraform
terraform init
terraform plan -out=tfplan
terraform apply tfplan
cd ../..

# Step 2: Verify network (already exists)
log_info "Step 2: Verifying network infrastructure"
cd dev/1.networking
terraform init
terraform plan
VPC_ID=$(terraform output -raw vpc_id)
log_info "VPC ID: ${VPC_ID}"
cd ../..

# Step 3: Deploy IoT Core
log_info "Step 3: Deploying AWS IoT Core infrastructure"
cd dev/2.iot_core
terraform init
terraform plan -out=tfplan
terraform apply tfplan
cd ../..

# Step 4: Deploy Data Layer
log_info "Step 4: Deploying data layer (DynamoDB + Timestream)"
cd dev/3.data_layer
terraform init
terraform plan -out=tfplan
terraform apply tfplan
cd ../..

# Step 5: Deploy IoT Rules
log_info "Step 5: Deploying IoT Rules Engine"
cd dev/4.iot_rules
terraform init
terraform plan -out=tfplan
terraform apply tfplan
cd ../..

# Step 6: Build Lambda functions
log_info "Step 6: Building Lambda functions"
cd dev/5.api_gateway/lambda/get_cameras
zip -r ../get_cameras.zip index.py
cd ../get_incidents
zip -r ../get_incidents.zip index.py
cd ../../..

# Step 7: Deploy API Gateway
log_info "Step 7: Deploying API Gateway and Lambda functions"
cd dev/5.api_gateway
terraform init
terraform plan -out=tfplan
terraform apply tfplan
API_ENDPOINT=$(terraform output -raw api_gateway_endpoint)
log_info "API Endpoint: ${API_ENDPOINT}"
cd ../..

# Summary
echo "=================================="
log_info "Deployment Complete!"
echo "=================================="
log_info "IoT Data Endpoint: $(cd dev/2.iot_core && terraform output -raw iot_data_endpoint)"
log_info "Device Registry Table: $(cd dev/3.data_layer && terraform output -raw device_registry_table_name)"
log_info "Incidents Table: $(cd dev/3.data_layer && terraform output -raw camera_incidents_table_name)"
log_info "API Endpoint: ${API_ENDPOINT}"
echo "=================================="
log_info "Next steps:"
echo "  1. Run validation tests: ./scripts/validate-infrastructure.sh"
echo "  2. Create IoT certificate for pilot site"
echo "  3. Deploy Greengrass Core (Week 3)"
echo "=================================="
```

---

### Validation Script
**File**: `scripts/validate-infrastructure.sh`

```bash
#!/bin/bash
set -e

# Infrastructure Validation Script
# Usage: ./scripts/validate-infrastructure.sh

REGION="ap-southeast-1"
ENVIRONMENT="dev"
PRODUCT="aismc"

GREEN='\033[0;32m'
RED='\033[0;31m'
NC='\033[0m'

function check_pass() {
    echo -e "${GREEN}✓${NC} $1"
}

function check_fail() {
    echo -e "${RED}✗${NC} $1"
    FAILED=true
}

FAILED=false

echo "=================================="
echo "Infrastructure Validation"
echo "=================================="

# Check Thing Groups
echo "Checking Thing Groups..."
if aws iot describe-thing-group --thing-group-name Vietnam --region ${REGION} > /dev/null 2>&1; then
    check_pass "Thing Group 'Vietnam' exists"
else
    check_fail "Thing Group 'Vietnam' not found"
fi

if aws iot describe-thing-group --thing-group-name Hanoi-Site-001 --region ${REGION} > /dev/null 2>&1; then
    check_pass "Thing Group 'Hanoi-Site-001' exists"
else
    check_fail "Thing Group 'Hanoi-Site-001' not found"
fi

# Check IoT Policies
echo "Checking IoT Policies..."
if aws iot get-policy --policy-name ${PRODUCT}-${ENVIRONMENT}-greengrass-core-policy --region ${REGION} > /dev/null 2>&1; then
    check_pass "IoT Policy 'greengrass-core-policy' exists"
else
    check_fail "IoT Policy 'greengrass-core-policy' not found"
fi

# Check DynamoDB Tables
echo "Checking DynamoDB Tables..."
if aws dynamodb describe-table --table-name ${PRODUCT}-${ENVIRONMENT}-device-registry --region ${REGION} > /dev/null 2>&1; then
    check_pass "DynamoDB table 'device-registry' exists"
else
    check_fail "DynamoDB table 'device-registry' not found"
fi

if aws dynamodb describe-table --table-name ${PRODUCT}-${ENVIRONMENT}-camera-incidents --region ${REGION} > /dev/null 2>&1; then
    check_pass "DynamoDB table 'camera-incidents' exists"
else
    check_fail "DynamoDB table 'camera-incidents' not found"
fi

# Check Timestream
echo "Checking Timestream Database..."
if aws timestream-write describe-database --database-name ${PRODUCT}-${ENVIRONMENT}-iot-metrics --region ${REGION} > /dev/null 2>&1; then
    check_pass "Timestream database 'iot-metrics' exists"
else
    check_fail "Timestream database 'iot-metrics' not found"
fi

# Check IoT Rules
echo "Checking IoT Rules..."
RULE_COUNT=$(aws iot list-topic-rules --region ${REGION} --query 'rules[?starts_with(ruleName, `aismc_dev`)]' --output json | jq length)
if [ "$RULE_COUNT" -ge "3" ]; then
    check_pass "IoT Rules configured (count: ${RULE_COUNT})"
else
    check_fail "Insufficient IoT Rules (expected: 3, found: ${RULE_COUNT})"
fi

# Check SNS Topics
echo "Checking SNS Topics..."
SNS_TOPICS=$(aws sns list-topics --region ${REGION} --query 'Topics[?contains(TopicArn, `aismc-dev`)]' --output json | jq length)
if [ "$SNS_TOPICS" -ge "3" ]; then
    check_pass "SNS topics configured (count: ${SNS_TOPICS})"
else
    check_fail "Insufficient SNS topics (expected: 3, found: ${SNS_TOPICS})"
fi

# Check API Gateway
echo "Checking API Gateway..."
cd dev/5.api_gateway
API_ID=$(terraform output -raw api_gateway_id 2>/dev/null || echo "")
if [ -n "$API_ID" ]; then
    check_pass "API Gateway deployed (ID: ${API_ID})"

    # Test API endpoint
    API_ENDPOINT=$(terraform output -raw api_gateway_endpoint)
    HTTP_CODE=$(curl -s -o /dev/null -w "%{http_code}" "${API_ENDPOINT}/cameras?limit=10")
    if [ "$HTTP_CODE" = "200" ]; then
        check_pass "API Gateway endpoint accessible (HTTP ${HTTP_CODE})"
    else
        check_fail "API Gateway endpoint failed (HTTP ${HTTP_CODE})"
    fi
else
    check_fail "API Gateway not found"
fi
cd ../..

# Check Lambda Functions
echo "Checking Lambda Functions..."
LAMBDA_COUNT=$(aws lambda list-functions --region ${REGION} --query 'Functions[?starts_with(FunctionName, `aismc-dev`)]' --output json | jq length)
if [ "$LAMBDA_COUNT" -ge "2" ]; then
    check_pass "Lambda functions deployed (count: ${LAMBDA_COUNT})"
else
    check_fail "Insufficient Lambda functions (expected: 2, found: ${LAMBDA_COUNT})"
fi

echo "=================================="
if [ "$FAILED" = true ]; then
    echo -e "${RED}Validation FAILED${NC}"
    echo "Please review errors above"
    exit 1
else
    echo -e "${GREEN}Validation PASSED${NC}"
    echo "All infrastructure components are operational"
    exit 0
fi
```

---

## 📊 COST ESTIMATION

### Week 1-2 Cost Breakdown

**File**: `claudedocs/COST-ESTIMATION.md`

```markdown
# Week 1-2 Cost Estimation

## Infrastructure Setup Phase (No Traffic)

### AWS IoT Core
- **Thing Registry**: Free (< 100 Things)
- **Device Shadow**: Free (< 100 shadows)
- **Rules Engine**: $0 (no messages)
- **Jobs**: $0 (no jobs running)
**Subtotal**: $0/month

### DynamoDB
- **DeviceRegistry Table**: On-Demand mode
  - Storage: 0 GB (empty)
  - Read/Write: Minimal testing
  - **Cost**: $0-2/month

- **CameraIncidents Table**: On-Demand mode
  - Storage: 0 GB (empty)
  - Read/Write: Minimal testing
  - **Cost**: $0-2/month

**Subtotal**: $0-4/month

### Timestream
- **Database**: $0 (fixed cost)
- **Memory Store**: 0 GB (no data)
- **Magnetic Store**: 0 GB (no data)
- **Queries**: $0 (no queries)
**Subtotal**: $0/month

### Lambda
- **Invocations**: < 1M/month (free tier)
- **Duration**: < 400,000 GB-seconds (free tier)
**Subtotal**: $0/month (within free tier)

### API Gateway
- **REST API calls**: < 1M/month (free tier)
- **Data transfer**: Minimal
**Subtotal**: $0/month (within free tier)

### SNS
- **Publish**: < 1,000 messages (testing)
- **Email notifications**: < 100 emails
**Subtotal**: $0/month (within free tier)

### CloudWatch
- **Logs**: ~1 GB/month
- **Metrics**: Standard metrics (free)
- **Dashboards**: 0 (not created yet)
**Subtotal**: $1/month

### S3
- **Terraform State**: < 1 GB
- **Certificate metadata**: < 100 MB
**Subtotal**: $0-1/month

---

## Total Estimated Cost (Week 1-2)

| Component | Cost/Month |
|-----------|------------|
| IoT Core | $0 |
| DynamoDB | $0-4 |
| Timestream | $0 |
| Lambda | $0 (free tier) |
| API Gateway | $0 (free tier) |
| SNS | $0 (free tier) |
| CloudWatch Logs | $1 |
| S3 | $0-1 |
| **TOTAL** | **$1-6/month** |

**Note**: This is infrastructure-only cost with no production traffic.
Week 3+ costs will increase with actual device connections and message traffic.

---

## Production Cost Projection (Week 8+)

For comparison, production with 15,000 cameras:

| Component | Cost/Month |
|-----------|------------|
| IoT Core (15K cameras) | $24 |
| DynamoDB | $3 |
| Timestream | $2 |
| Lambda | $0 (within free tier) |
| API Gateway | $0 (within free tier) |
| **TOTAL** | **~$29/month** |

**Cost per camera**: $0.0019/month (vs $0.34/month with Vertex AI)
**Savings**: 99.4% compared to Cloud-only polling approach
```

---

## 🎓 TRAINING MATERIALS

### Quick Reference Guide
**File**: `claudedocs/QUICK-REFERENCE.md`

```markdown
# Week 1-2 Quick Reference Guide

## Terraform Commands

### Initialize and Apply
```bash
# Initialize Terraform
cd dev/2.iot_core
terraform init

# Plan changes
terraform plan -out=tfplan

# Apply changes
terraform apply tfplan

# View outputs
terraform output

# Destroy resources
terraform destroy
```

### State Management
```bash
# List resources
terraform state list

# Show resource details
terraform state show aws_iot_thing_group.vietnam

# Pull remote state
terraform state pull
```

---

## AWS CLI Commands

### IoT Core
```bash
# List Thing Groups
aws iot list-thing-groups --region ap-southeast-1

# Describe Thing Group
aws iot describe-thing-group \
  --thing-group-name Vietnam \
  --region ap-southeast-1

# List IoT Policies
aws iot list-policies --region ap-southeast-1

# Get IoT endpoint
aws iot describe-endpoint \
  --endpoint-type iot:Data-ATS \
  --region ap-southeast-1
```

### DynamoDB
```bash
# Describe table
aws dynamodb describe-table \
  --table-name aismc-dev-device-registry \
  --region ap-southeast-1

# Scan table
aws dynamodb scan \
  --table-name aismc-dev-device-registry \
  --limit 10 \
  --region ap-southeast-1

# Get item
aws dynamodb get-item \
  --table-name aismc-dev-camera-incidents \
  --key '{"incident_id":{"S":"test-001"},"timestamp":{"S":"2025-12-29T10:00:00Z"}}' \
  --region ap-southeast-1
```

### IoT Data Publishing (Testing)
```bash
# Publish to incidents topic
aws iot-data publish \
  --topic cameras/site-001/incidents \
  --payload '{"incident_id":"test-001","site_id":"site-001","timestamp":"2025-12-29T10:00:00Z"}' \
  --region ap-southeast-1

# Publish to registry topic
aws iot-data publish \
  --topic cameras/site-001/registry \
  --payload file://test-camera.json \
  --region ap-southeast-1
```

---

## Common Troubleshooting

### Issue: Terraform state lock
**Solution**:
```bash
# Force unlock (use with caution)
terraform force-unlock LOCK_ID
```

### Issue: DynamoDB table not found
**Solution**:
```bash
# Verify table exists
aws dynamodb list-tables --region ap-southeast-1

# Check Terraform state
cd dev/3.data_layer
terraform state list | grep dynamodb
```

### Issue: IoT Rule not triggering
**Solution**:
```bash
# Check CloudWatch Logs for errors
aws logs tail /aws/iot/rules/aismc-dev/errors --follow

# Test rule SQL manually
aws iot test-invoke-authorizer --authorizer-name test
```

### Issue: Lambda timeout
**Solution**:
```bash
# Check Lambda logs
aws logs tail /aws/lambda/aismc-dev-get-cameras --follow

# Increase timeout in Terraform
# In lambda.tf: timeout = 60
```

---

## Resource Naming Convention

```
Format: {product}-{environment}-{resource-type}-{name}

Examples:
- aismc-dev-device-registry (DynamoDB table)
- aismc-dev-greengrass-core-policy (IoT Policy)
- aismc-dev-get-cameras (Lambda function)
- Vietnam (Thing Group - exception, no prefix)
```

---

## File Structure Reference

```
dev/
├── 2.iot_core/
│   ├── main.tf              # Thing Groups
│   ├── iot_policies.tf      # IoT Policies
│   ├── certificates.tf      # Cert infrastructure
│   ├── data.tf              # Data sources
│   ├── locals.tf            # Local variables
│   ├── provider.tf          # AWS provider
│   └── outputs.tf           # Outputs
│
├── 3.data_layer/
│   ├── dynamodb.tf          # DynamoDB tables
│   ├── timestream.tf        # Timestream DB
│   ├── locals.tf
│   ├── provider.tf
│   └── outputs.tf
│
├── 4.iot_rules/
│   ├── main.tf              # IoT Rules
│   ├── sns.tf               # SNS topics
│   ├── variables.tf
│   ├── locals.tf
│   ├── provider.tf
│   └── outputs.tf
│
└── 5.api_gateway/
    ├── main.tf              # API Gateway
    ├── lambda.tf            # Lambda functions
    ├── lambda/
    │   ├── get_cameras/
    │   │   └── index.py
    │   └── get_incidents/
    │       └── index.py
    ├── locals.tf
    ├── provider.tf
    └── outputs.tf
```
```

---

## 📋 IMPLEMENTATION CHECKLIST

### Complete Task List
**File**: `claudedocs/IMPLEMENTATION-CHECKLIST.md`

```markdown
# Week 1-2 Implementation Checklist

## Prerequisites
- [ ] AWS accounts created (aismc-devops, aismc-dev)
- [ ] AWS CLI installed and configured
- [ ] Terraform 1.5+ installed
- [ ] Git repository initialized
- [ ] Access to cluster-nonprod-iac-main template

---

## Day 1: Foundation Setup

### Morning (4 hours)
- [ ] Review existing terraform template structure
- [ ] Create ops/1.organization/ directory
- [ ] Write organization Terraform code
- [ ] Apply organization setup
- [ ] Verify accounts created

### Afternoon (4 hours)
- [ ] Create dev/0.iam_assume_role_terraform/iot_roles.tf
- [ ] Define IoT Core service role
- [ ] Define Greengrass Core role
- [ ] Define Lambda execution role
- [ ] Apply IAM roles
- [ ] Test role assumptions

---

## Day 2: Network Verification

### Morning (4 hours)
- [ ] Verify existing VPC configuration
- [ ] Check subnet CIDRs match proposal
- [ ] Verify NAT gateways operational
- [ ] Test connectivity from private subnets
- [ ] Document network architecture

### Afternoon (4 hours)
- [ ] Setup S3 backend for new modules
- [ ] Configure Terraform remote state
- [ ] Test state locking
- [ ] Create deployment scripts directory
- [ ] Write initial deployment documentation

---

## Day 3: IoT Core - Thing Groups

### Morning (4 hours)
- [ ] Create _module/aws/iot/thing_group/
- [ ] Write Thing Group module code
- [ ] Test module with single Thing Group
- [ ] Create dev/2.iot_core/ directory
- [ ] Write main.tf for hierarchy

### Afternoon (4 hours)
- [ ] Deploy Vietnam root Thing Group
- [ ] Deploy Regional Thing Groups (3)
- [ ] Deploy Hanoi-Site-001 Thing Group
- [ ] Verify hierarchy in AWS Console
- [ ] Test Thing Group queries

---

## Day 4: IoT Core - Policies

### Morning (4 hours)
- [ ] Create _module/aws/iot/iot_policy/
- [ ] Write IoT Policy module code
- [ ] Define Greengrass Core policy document
- [ ] Define read-only policy document
- [ ] Test policy syntax

### Afternoon (4 hours)
- [ ] Deploy Greengrass Core policy
- [ ] Deploy read-only policy
- [ ] Verify policies in IoT Console
- [ ] Test policy attachment (dry-run)
- [ ] Document policy permissions

---

## Day 5: IoT Core - Certificates

### Morning (4 hours)
- [ ] Create certificates.tf
- [ ] Setup S3 bucket for cert metadata
- [ ] Create DynamoDB cert registry table
- [ ] Write certificate creation script
- [ ] Test script with dummy cert

### Afternoon (4 hours)
- [ ] Add IoT endpoints data source
- [ ] Create outputs.tf for IoT Core
- [ ] Run full IoT Core deployment
- [ ] Validate all Thing Groups exist
- [ ] Test IoT Data endpoint connectivity

---

## Day 6: Data Layer - DynamoDB

### Morning (4 hours)
- [ ] Create _module/aws/data/dynamodb/
- [ ] Write DynamoDB module code
- [ ] Test module with sample table
- [ ] Create dev/3.data_layer/ directory
- [ ] Write dynamodb.tf

### Afternoon (4 hours)
- [ ] Deploy DeviceRegistry table
- [ ] Deploy CameraIncidents table
- [ ] Verify GSI indexes created
- [ ] Test table queries
- [ ] Verify TTL configuration

---

## Day 7: Data Layer - Timestream

### Morning (4 hours)
- [ ] Create timestream.tf
- [ ] Define Timestream database
- [ ] Define camera-metrics table
- [ ] Define site-metrics table
- [ ] Define system-metrics table

### Afternoon (4 hours)
- [ ] Deploy Timestream resources
- [ ] Verify retention policies
- [ ] Test Timestream write (sample data)
- [ ] Test Timestream query
- [ ] Create data layer outputs.tf

---

## Day 8: IoT Rules Engine

### Morning (4 hours)
- [ ] Create dev/4.iot_rules/ directory
- [ ] Write main.tf with data sources
- [ ] Define incidents_to_dynamodb rule
- [ ] Define registry_to_dynamodb rule
- [ ] Define metrics_to_timestream rule

### Afternoon (4 hours)
- [ ] Define critical_alerts_to_sns rule
- [ ] Create CloudWatch Log Group
- [ ] Deploy all IoT Rules
- [ ] Verify rules in IoT Console
- [ ] Test each rule with sample data

---

## Day 9: SNS Integration

### Morning (4 hours)
- [ ] Create sns.tf
- [ ] Define critical alerts topic
- [ ] Define warning alerts topic
- [ ] Define operational notifications topic
- [ ] Add email subscription

### Afternoon (4 hours)
- [ ] Deploy SNS topics
- [ ] Confirm email subscription
- [ ] Test SNS publishing
- [ ] Verify email delivery
- [ ] Create IoT Rules outputs.tf

---

## Day 10: API Gateway & Lambda

### Morning (4 hours)
- [ ] Create dev/5.api_gateway/ directory
- [ ] Write main.tf for API Gateway
- [ ] Define /cameras resource
- [ ] Define /incidents resource
- [ ] Define /metrics resource

### Afternoon (4 hours)
- [ ] Write lambda.tf
- [ ] Create Lambda function code (get_cameras)
- [ ] Create Lambda function code (get_incidents)
- [ ] Build Lambda deployment packages
- [ ] Deploy API Gateway + Lambda
- [ ] Test API endpoints

---

## Final Validation

### End-to-End Tests
- [ ] Run validation script
- [ ] Test device registry flow
- [ ] Test incident alert flow
- [ ] Test metrics flow
- [ ] Verify API responses

### Documentation
- [ ] Update architecture diagrams
- [ ] Document all outputs
- [ ] Create runbooks for operations
- [ ] Write handover documentation

### Cost & Security
- [ ] Verify costs within budget
- [ ] Run security audit script
- [ ] Check IAM least privilege
- [ ] Verify encryption at rest

---

## Deliverables Checklist

- [ ] All Terraform modules in _module/
- [ ] All environments in dev/
- [ ] Deployment scripts in scripts/
- [ ] Documentation in claudedocs/
- [ ] Validation scripts working
- [ ] Cost estimation confirmed
- [ ] Security audit passed
- [ ] Handover document complete

**Sign-off**: ________________
**Date**: __________________
```

---

## 🎯 SUCCESS METRICS

**Completion Criteria**:

1. ✅ All Terraform modules created and tested
2. ✅ AWS Organization with dev account operational
3. ✅ IAM roles configured with least privilege
4. ✅ IoT Core hierarchy: Vietnam → Regions → Sites
5. ✅ DynamoDB tables with indexes operational
6. ✅ Timestream database configured
7. ✅ IoT Rules routing to all destinations
8. ✅ SNS alerts configured and tested
9. ✅ API Gateway + Lambda responding
10. ✅ End-to-end test successful
11. ✅ Infrastructure cost < $10/month
12. ✅ Security audit passed
13. ✅ Documentation complete

**Key Metrics**:
- Deployment success rate: 100%
- Validation test pass rate: 100%
- Cost variance: < 10%
- Time to deploy: < 2 hours (automated)

---

## NEXT STEPS (Week 3)

After Week 1-2 completion:

1. **Week 3**: Edge Components Development
   - Greengrass Component #1: Camera Registry Sync
   - Greengrass Component #2: Incident Forwarder
   - SQLite database schema implementation

2. **Week 4**: Pilot Site Deployment
   - Deploy Greengrass Core to Hanoi Site 001
   - Certificate provisioning
   - DMP/SmartHUB integration testing

3. **Week 5-6**: Performance Testing
   - Scale to 15,000 cameras
   - Load testing
   - Optimization

---

**Document Version**: 1.0
**Last Updated**: 2025-12-29
**Author**: Claude Code
**Status**: Ready for Implementation
