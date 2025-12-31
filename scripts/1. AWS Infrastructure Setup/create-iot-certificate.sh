#!/bin/bash
set -e

# IoT Certificate Creation Script
# Usage: ./scripts/create-iot-certificate.sh <site-id> [thing-name]

SITE_ID=$1
THING_NAME=${2:-"SmartHUB-${SITE_ID}"}
REGION="ap-southeast-1"
PRODUCT="aismc"
ENVIRONMENT="dev"

if [ -z "$SITE_ID" ]; then
    echo "Usage: $0 <site-id> [thing-name]"
    echo "Example: $0 site-001"
    exit 1
fi

GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m'

function log_info() {
    echo -e "${GREEN}[INFO]${NC} $1"
}

function log_warn() {
    echo -e "${YELLOW}[WARN]${NC} $1"
}

echo "=================================="
echo "Creating IoT Certificate"
echo "=================================="
echo "Site ID: ${SITE_ID}"
echo "Thing Name: ${THING_NAME}"
echo "Region: ${REGION}"
echo "=================================="

# Create certificate and keys
log_info "Creating certificate and keys..."
CERT_OUTPUT=$(aws iot create-keys-and-certificate \
  --set-as-active \
  --region ${REGION} \
  --output json)

CERT_ARN=$(echo $CERT_OUTPUT | jq -r '.certificateArn')
CERT_ID=$(echo $CERT_OUTPUT | jq -r '.certificateId')
CERT_PEM=$(echo $CERT_OUTPUT | jq -r '.certificatePem')
PUBLIC_KEY=$(echo $CERT_OUTPUT | jq -r '.keyPair.PublicKey')
PRIVATE_KEY=$(echo $CERT_OUTPUT | jq -r '.keyPair.PrivateKey')

log_info "Certificate created: ${CERT_ID}"
log_info "Certificate ARN: ${CERT_ARN}"

# Save certificate and keys to files
CERT_DIR="certs/${SITE_ID}"
mkdir -p ${CERT_DIR}

echo "${CERT_PEM}" > ${CERT_DIR}/certificate.pem.crt
echo "${PUBLIC_KEY}" > ${CERT_DIR}/public.pem.key
echo "${PRIVATE_KEY}" > ${CERT_DIR}/private.pem.key

# Download Amazon Root CA
curl -s https://www.amazontrust.com/repository/AmazonRootCA1.pem > ${CERT_DIR}/AmazonRootCA1.pem

log_info "Certificate files saved to: ${CERT_DIR}/"
log_info "  - certificate.pem.crt"
log_info "  - public.pem.key"
log_info "  - private.pem.key"
log_info "  - AmazonRootCA1.pem"

# Attach policy to certificate
POLICY_NAME="${PRODUCT}-${ENVIRONMENT}-greengrass-core-policy"
log_info "Attaching policy: ${POLICY_NAME}"

aws iot attach-policy \
  --policy-name ${POLICY_NAME} \
  --target ${CERT_ARN} \
  --region ${REGION}

log_info "Policy attached successfully"

# Create Thing (optional - may already exist)
log_info "Creating Thing: ${THING_NAME}"
aws iot create-thing \
  --thing-name ${THING_NAME} \
  --attribute-payload "attributes={site_id=${SITE_ID}}" \
  --region ${REGION} 2>/dev/null || log_warn "Thing may already exist"

# Attach certificate to Thing
log_info "Attaching certificate to Thing"
aws iot attach-thing-principal \
  --thing-name ${THING_NAME} \
  --principal ${CERT_ARN} \
  --region ${REGION}

log_info "Certificate attached to Thing successfully"

# Add to Thing Group
THING_GROUP="Hanoi-Site-001" # TODO: Make this dynamic based on site_id
log_info "Adding Thing to Thing Group: ${THING_GROUP}"
aws iot add-thing-to-thing-group \
  --thing-name ${THING_NAME} \
  --thing-group-name ${THING_GROUP} \
  --region ${REGION} 2>/dev/null || log_warn "Thing may already be in group"

# Store certificate metadata in DynamoDB
log_info "Storing certificate metadata in DynamoDB"
aws dynamodb put-item \
  --table-name ${PRODUCT}-${ENVIRONMENT}-certificate-registry \
  --item "{
    \"certificate_id\": {\"S\": \"${CERT_ID}\"},
    \"thing_name\": {\"S\": \"${THING_NAME}\"},
    \"site_id\": {\"S\": \"${SITE_ID}\"},
    \"status\": {\"S\": \"ACTIVE\"},
    \"created_at\": {\"S\": \"$(date -u +%Y-%m-%dT%H:%M:%SZ)\"},
    \"certificate_arn\": {\"S\": \"${CERT_ARN}\"}
  }" \
  --region ${REGION}

echo "=================================="
log_info "Certificate Creation Complete!"
echo "=================================="
echo "Certificate ID: ${CERT_ID}"
echo "Certificate files: ${CERT_DIR}/"
echo ""
log_warn "IMPORTANT: Keep the private key secure!"
echo "=================================="
