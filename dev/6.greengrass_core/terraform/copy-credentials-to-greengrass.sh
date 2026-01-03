#!/bin/bash

# ============================================================================
# Copy Greengrass Credentials Script
# ============================================================================
# This script copies the generated certificates and keys to the Greengrass
# installation directory with proper permissions.
#
# Thing Name: GreengrassCore-site001-hanoi
# ============================================================================

set -e

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

# Configuration
THING_NAME="GreengrassCore-site001-hanoi"
CREDENTIALS_PATH="./greengrass-credentials"
GREENGRASS_ROOT="/greengrass/v2"

echo -e "${GREEN}================================================${NC}"
echo -e "${GREEN}Greengrass Credentials Copy Script${NC}"
echo -e "${GREEN}================================================${NC}"
echo ""

# Check if running as root
if [ "$EUID" -ne 0 ]; then
    echo -e "${RED}ERROR: This script must be run as root (use sudo)${NC}"
    exit 1
fi

# Check if Greengrass directory exists
if [ ! -d "$GREENGRASS_ROOT" ]; then
    echo -e "${RED}ERROR: Greengrass directory not found: $GREENGRASS_ROOT${NC}"
    exit 1
fi

# Check if credentials exist
if [ ! -d "$CREDENTIALS_PATH" ]; then
    echo -e "${RED}ERROR: Credentials directory not found: $CREDENTIALS_PATH${NC}"
    exit 1
fi

# Stop Greengrass service
echo -e "${YELLOW}[1/5] Stopping Greengrass service...${NC}"
systemctl stop greengrass.service || true
sleep 2

# Backup existing certificates
echo -e "${YELLOW}[2/5] Backing up existing certificates...${NC}"
BACKUP_DIR="$GREENGRASS_ROOT/backup-$(date +%Y%m%d-%H%M%S)"
mkdir -p "$BACKUP_DIR"

if [ -f "$GREENGRASS_ROOT/thingCert.crt" ]; then
    cp "$GREENGRASS_ROOT/thingCert.crt" "$BACKUP_DIR/"
    echo "  ✓ Backed up thingCert.crt"
fi

if [ -f "$GREENGRASS_ROOT/privKey.key" ]; then
    cp "$GREENGRASS_ROOT/privKey.key" "$BACKUP_DIR/"
    echo "  ✓ Backed up privKey.key"
fi

if [ -f "$GREENGRASS_ROOT/rootCA.pem" ]; then
    cp "$GREENGRASS_ROOT/rootCA.pem" "$BACKUP_DIR/"
    echo "  ✓ Backed up rootCA.pem"
fi

# Copy new certificates
echo -e "${YELLOW}[3/5] Copying new certificates...${NC}"

cp "$CREDENTIALS_PATH/$THING_NAME-certificate.pem.crt" "$GREENGRASS_ROOT/thingCert.crt"
echo "  ✓ Copied certificate"

cp "$CREDENTIALS_PATH/$THING_NAME-private.pem.key" "$GREENGRASS_ROOT/privKey.key"
echo "  ✓ Copied private key"

cp "$CREDENTIALS_PATH/AmazonRootCA1.pem" "$GREENGRASS_ROOT/rootCA.pem"
echo "  ✓ Copied Root CA"

# Set permissions
echo -e "${YELLOW}[4/5] Setting permissions...${NC}"

chown root:ggc_group "$GREENGRASS_ROOT/thingCert.crt"
chmod 644 "$GREENGRASS_ROOT/thingCert.crt"
echo "  ✓ Set permissions for certificate"

chown root:ggc_group "$GREENGRASS_ROOT/privKey.key"
chmod 640 "$GREENGRASS_ROOT/privKey.key"
echo "  ✓ Set permissions for private key"

chown root:ggc_group "$GREENGRASS_ROOT/rootCA.pem"
chmod 644 "$GREENGRASS_ROOT/rootCA.pem"
echo "  ✓ Set permissions for Root CA"

# Start Greengrass service
echo -e "${YELLOW}[5/5] Starting Greengrass service...${NC}"
systemctl start greengrass.service
sleep 3

# Check status
echo ""
echo -e "${GREEN}================================================${NC}"
echo -e "${GREEN}Credentials copied successfully!${NC}"
echo -e "${GREEN}================================================${NC}"
echo ""
echo "Service Status:"
systemctl status greengrass.service --no-pager | head -10
echo ""
echo -e "${YELLOW}Next Steps:${NC}"
echo "1. Update Greengrass configuration with new Thing name: $THING_NAME"
echo "2. Verify connectivity: sudo /greengrass/v2/bin/greengrass-cli component list"
echo "3. Check logs: sudo tail -f /greengrass/v2/logs/greengrass.log"
echo ""
echo "Backup location: $BACKUP_DIR"
echo ""
