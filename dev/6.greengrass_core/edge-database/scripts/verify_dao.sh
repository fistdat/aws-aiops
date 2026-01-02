#!/bin/bash
# Verification script for Database DAO Layer deployment
# Version: 1.0.0

set -e

# Color codes
GREEN='\033[0;32m'
RED='\033[0;31m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

# Log functions
log_info() {
    echo -e "${GREEN}[INFO]${NC} $1"
}

log_error() {
    echo -e "${RED}[ERROR]${NC} $1"
}

echo "========================================================================"
echo "  Database DAO Layer Deployment Verification"
echo "========================================================================"
echo ""

# 1. Check Python3 installation
log_info "Checking Python3 installation..."
if command -v python3 &> /dev/null; then
    PYTHON_VERSION=$(python3 --version)
    log_info "✅ Python3 installed: $PYTHON_VERSION"
else
    log_error "❌ Python3 not found"
    exit 1
fi
echo ""

# 2. Check database directory
log_info "Checking database directory..."
DB_DIR="/var/greengrass/database"
if [ -d "$DB_DIR" ]; then
    log_info "✅ Database directory exists: $DB_DIR"
else
    log_error "❌ Database directory not found: $DB_DIR"
    exit 1
fi
echo ""

# 3. Check SQLite database file
log_info "Checking SQLite database file..."
DB_FILE="$DB_DIR/greengrass.db"
if [ -f "$DB_FILE" ]; then
    log_info "✅ Database file exists: $DB_FILE"
else
    log_error "❌ Database file not found: $DB_FILE"
    exit 1
fi
echo ""

# 4. Check DAO Layer files
log_info "Checking DAO Layer files..."
DAO_BASE="/greengrass/v2/components/common"

FILES=(
    "$DAO_BASE/database/__init__.py"
    "$DAO_BASE/database/connection.py"
    "$DAO_BASE/database/dao.py"
    "$DAO_BASE/utils/__init__.py"
    "$DAO_BASE/utils/ngsi_ld.py"
)

for file in "${FILES[@]}"; do
    if [ -f "$file" ]; then
        log_info "✅ File exists: $(basename $file)"
    else
        log_error "❌ File not found: $file"
        exit 1
    fi
done
echo ""

# 5. Test Python imports
log_info "Testing Python imports..."
python3 << 'EOF'
import sys
sys.path.insert(0, '/greengrass/v2/components/common')

try:
    from database.connection import DatabaseManager
    print("✅ DatabaseManager import successful")
    from database.dao import CameraDAO, IncidentDAO, MessageQueueDAO, SyncLogDAO, ConfigurationDAO
    print("✅ DAO classes import successful")
    from utils.ngsi_ld import transform_camera_to_ngsi_ld, transform_incident_to_ngsi_ld
    print("✅ NGSI-LD utilities import successful")
except ImportError as e:
    print(f"❌ Import failed: {e}")
    sys.exit(1)
EOF

if [ $? -eq 0 ]; then
    log_info "✅ All Python imports successful"
else
    log_error "❌ Python import tests failed"
    exit 1
fi
echo ""

# 6. Test database connection
log_info "Testing database connection..."
python3 << 'EOF'
import sys
sys.path.insert(0, '/greengrass/v2/components/common')
from database.connection import DatabaseManager

try:
    db = DatabaseManager()
    health = db.health_check()
    if health['status'] == 'healthy':
        print(f"✅ Database healthy - Cameras: {health.get('cameras', 0)}, Incidents: {health.get('incidents', 0)}")
    else:
        print(f"❌ Database unhealthy: {health}")
        sys.exit(1)
except Exception as e:
    print(f"❌ Database connection failed: {e}")
    sys.exit(1)
EOF

if [ $? -eq 0 ]; then
    log_info "✅ Database connection test passed"
else
    log_error "❌ Database connection test failed"
    exit 1
fi
echo ""

echo "========================================================================"
log_info "✅ ALL VERIFICATION CHECKS PASSED"
echo "========================================================================"
echo ""

exit 0
