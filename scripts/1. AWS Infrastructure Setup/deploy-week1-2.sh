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
VPC_ID=$(terraform output -raw vpc_id 2>/dev/null || echo "")
if [ -n "$VPC_ID" ]; then
    log_info "VPC ID: ${VPC_ID}"
else
    log_warn "VPC not found - may need to create networking first"
fi
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
log_info "Step 6: Building Lambda functions (already packaged by Terraform)"
# Lambda packages are created by archive_file data source in Terraform

# Step 7: Deploy API Gateway
log_info "Step 7: Deploying API Gateway and Lambda functions"
cd dev/5.api_gateway
terraform init
terraform plan -out=tfplan
terraform apply tfplan
API_ENDPOINT=$(terraform output -raw api_gateway_endpoint 2>/dev/null || echo "")
cd ../..

# Summary
echo "=================================="
log_info "Deployment Complete!"
echo "=================================="
if [ -n "$API_ENDPOINT" ]; then
    log_info "API Endpoint: ${API_ENDPOINT}"
fi
echo "=================================="
log_info "Next steps:"
echo "  1. Run validation tests: ./scripts/validate-infrastructure.sh"
echo "  2. Check SNS email subscription in your inbox"
echo "  3. Test API endpoints:"
if [ -n "$API_ENDPOINT" ]; then
    echo "     curl ${API_ENDPOINT}/cameras?limit=10"
    echo "     curl ${API_ENDPOINT}/incidents?limit=10"
fi
echo "=================================="
