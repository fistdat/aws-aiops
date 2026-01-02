#!/bin/bash
# ============================================================================
# Install Python DAO Layer to Greengrass
# Version: 1.0.0
# Purpose: Deploy Python DAO code to Greengrass Python path
# ============================================================================

set -e  # Exit on error

# Configuration
SOURCE_DIR="$(dirname "$0")/../python-dao"
TARGET_DIR="/greengrass/v2/packages/artifacts-unarchived/greengrass_database"
GG_USER="${GREENGRASS_USER:-ggc_user}"
GG_GROUP="${GREENGRASS_GROUP:-ggc_group}"

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m'

log_info() {
    echo -e "${GREEN}[INFO]${NC} $1"
}

log_warn() {
    echo -e "${YELLOW}[WARN]${NC} $1"
}

log_error() {
    echo -e "${RED}[ERROR]${NC} $1"
}

# Check if running as sudo
if [ "$EUID" -ne 0 ]; then
    log_error "Please run with sudo"
    exit 1
fi

log_info "Installing Python DAO layer to Greengrass..."

# Step 1: Create target directory
log_info "Creating target directory: $TARGET_DIR"
mkdir -p "$TARGET_DIR"

# Step 2: Copy Python files
log_info "Copying Python DAO files..."
cp -r "$SOURCE_DIR"/* "$TARGET_DIR/"

# Step 3: Set permissions
log_info "Setting permissions..."
chown -R "$GG_USER:$GG_GROUP" "$TARGET_DIR"
chmod -R 755 "$TARGET_DIR"
chmod 644 "$TARGET_DIR"/*.py

# Step 4: Verify installation
log_info "Verifying installation..."
if [ -f "$TARGET_DIR/__init__.py" ] && [ -f "$TARGET_DIR/connection.py" ] && [ -f "$TARGET_DIR/dao.py" ]; then
    log_info "✅ Python DAO files copied successfully"
else
    log_error "Python DAO files missing!"
    exit 1
fi

# Step 5: Test Python import (if Python3 available)
if command -v python3 &> /dev/null; then
    log_info "Testing Python import..."
    export PYTHONPATH="$TARGET_DIR:$PYTHONPATH"

    if python3 -c "import connection; import dao; print('Import successful')" 2>/dev/null; then
        log_info "✅ Python imports successful"
    else
        log_warn "⚠️  Python import test failed (may work in Greengrass context)"
    fi
fi

log_info "✅ Python DAO layer installation completed!"
log_info "Installation path: $TARGET_DIR"

exit 0
