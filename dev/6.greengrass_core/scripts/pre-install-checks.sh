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
