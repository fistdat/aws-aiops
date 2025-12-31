# AIOps IoC Platform - Infrastructure as Code

Week 1-2 AWS Infrastructure Setup for AIOps IoC Platform

## Overview

This repository contains Terraform infrastructure code for deploying the AIOps IoC Platform on AWS. The infrastructure supports a scalable, event-driven IoT system for monitoring 100,000+ cameras across Vietnam.

## Architecture

```
AWS Cloud Infrastructure
├── IoT Core: Thing Groups, Policies, MQTT
├── Data Layer: DynamoDB + Timestream
├── Integration: IoT Rules Engine + SNS
└── API Layer: API Gateway + Lambda
```

## Directory Structure

```
cluster-nonprod-iac-main/
├── ops/                          # Operational infrastructure
│   ├── 0.init_s3_backend/        # Terraform state backend
│   └── 1.organization/           # AWS Organization setup
│
├── dev/                          # Development environment
│   ├── 0.iam_assume_role_terraform/  # IAM roles + IoT roles
│   ├── 1.networking/             # VPC (existing)
│   ├── 2.iot_core/               # IoT Core infrastructure
│   ├── 3.data_layer/             # DynamoDB + Timestream
│   ├── 4.iot_rules/              # IoT Rules Engine + SNS
│   └── 5.api_gateway/            # API Gateway + Lambda
│
├── _module/                      # Reusable Terraform modules
│   └── aws/
│       ├── iot/                  # IoT-specific modules
│       └── data/                 # Data storage modules
│
├── scripts/                      # Automation scripts
└── claudedocs/                   # Documentation
```

## Quick Start

### Prerequisites

- AWS CLI v2.x installed and configured
- Terraform 1.5+ installed
- jq (for validation scripts)
- Appropriate AWS credentials

### Deployment

**Option 1: Automated Deployment (Recommended)**
```bash
# Deploy everything in one command
./scripts/deploy-week1-2.sh

# Validate deployment
./scripts/validate-infrastructure.sh
```

**Option 2: Manual Step-by-Step Deployment**
```bash
# 1. Initialize S3 backend
cd ops/0.init_s3_backend
terraform init && terraform apply
cd ../..

# 2. Deploy IAM roles
cd dev/0.iam_assume_role_terraform
terraform init && terraform apply
cd ../..

# 3. Deploy IoT Core
cd dev/2.iot_core
terraform init && terraform apply
cd ../..

# 4. Deploy Data Layer
cd dev/3.data_layer
terraform init && terraform apply
cd ../..

# 5. Deploy IoT Rules
cd dev/4.iot_rules
terraform init && terraform apply
cd ../..

# 6. Deploy API Gateway
cd dev/5.api_gateway
terraform init && terraform apply
cd ../..
```

### Testing

```bash
# Create IoT certificate for pilot site
./scripts/create-iot-certificate.sh site-001

# Test message publishing
./scripts/test-iot-message.sh cameras/site-001/incidents

# Query API endpoints
API_ENDPOINT=$(cd dev/5.api_gateway && terraform output -raw api_gateway_endpoint)
curl "${API_ENDPOINT}/cameras?limit=10"
curl "${API_ENDPOINT}/incidents?limit=10"
```

## Infrastructure Components

### IoT Core (dev/2.iot_core)
- Thing Groups: Vietnam → Regions → Sites
- IoT Policies: Greengrass Core, Read-only
- Certificate management infrastructure

### Data Layer (dev/3.data_layer)
- **DynamoDB DeviceRegistry**: Camera catalog (15K cameras)
- **DynamoDB CameraIncidents**: Real-time incident tracking
- **Timestream**: Time-series metrics (camera, site, system)

### Integration Layer (dev/4.iot_rules)
- **IoT Rules**: Route messages to DynamoDB, SNS, Timestream
- **SNS Topics**: Critical/Warning/Operational alerts

### API Layer (dev/5.api_gateway)
- **API Gateway**: REST API for dashboard
- **Lambda Functions**: Query handlers (cameras, incidents)

## Cost Estimation

- **Week 1-2 Setup**: $1-6/month (infrastructure only)
- **Production (15K cameras)**: ~$29/month
- **Cost per camera**: $0.0019/month
- **vs Polling Approach**: 99.91% savings

## Security

- ✅ Certificate-based authentication (X.509)
- ✅ Encryption at rest (S3, DynamoDB, Timestream)
- ✅ Encryption in transit (TLS 1.3)
- ✅ Least privilege IAM roles
- ✅ VPC isolation

## Outputs

After deployment, retrieve outputs:

```bash
# IoT Core endpoints
cd dev/2.iot_core && terraform output

# DynamoDB table names
cd dev/3.data_layer && terraform output

# API Gateway endpoint
cd dev/5.api_gateway && terraform output api_gateway_endpoint
```

## Troubleshooting

See [claudedocs/QUICK-REFERENCE.md](claudedocs/QUICK-REFERENCE.md) for common issues and solutions.

## Next Steps (Week 3+)

1. Develop Greengrass Components
2. Implement SQLite database schema
3. Deploy pilot site (Hanoi Site 001)
4. Integrate with DMP and SmartHUB

## Documentation

- **[WEEK-1-2-INFRASTRUCTURE-PLAN.md](claudedocs/WEEK-1-2-INFRASTRUCTURE-PLAN.md)**: Comprehensive deployment plan
- **[EXECUTIVE-SUMMARY.md](claudedocs/EXECUTIVE-SUMMARY.md)**: High-level overview
- **[PRECONFIG-STRUCTURE.md](claudedocs/PRECONFIG-STRUCTURE.md)**: Directory structure and configuration

## Support

For issues or questions:
1. Check documentation in `claudedocs/`
2. Run validation script: `./scripts/validate-infrastructure.sh`
3. Review CloudWatch logs
4. Check Terraform state: `terraform state list`

## License

Internal use only - AIS MC AIOps IoC Platform
