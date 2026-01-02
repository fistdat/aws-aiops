# Edge Database DAO Layer

**Version**: 1.0.0
**Status**: Ready for Deployment
**Managed By**: Terraform

## Purpose

Provides a robust Data Access Object (DAO) layer for AWS IoT Greengrass Core to interact with local SQLite database. Includes NGSI-LD transformation utilities for standardized data format.

## Components

### 1. Database Package (`src/database/`)

#### `connection.py` - DatabaseManager
- Singleton pattern for thread-safe database access
- Connection pooling with WAL mode enabled
- Health check functionality
- Automatic commit/rollback handling

#### `dao.py` - Data Access Objects
- **CameraDAO**: Camera registry CRUD operations
  - `insert()`, `batch_upsert()`, `get_by_id()`, `update_status()`
  - Support for filtering by site_id and status
- **IncidentDAO**: Incident management with sync tracking
  - `insert()`, `get_pending_sync()`, `mark_synced()`, `update_resolved()`
  - Priority-based retrieval (critical first)
- **MessageQueueDAO**: Message queue with retry logic
  - `enqueue()`, `get_pending()`, `mark_sent()`, `increment_attempt()`
  - Automatic failure marking after max attempts
- **SyncLogDAO**: Audit trail for synchronization operations
  - `log()`, `get_recent()`, `get_last_successful_sync()`
- **ConfigurationDAO**: Configuration key-value store
  - `get()`, `set()`, `get_all()`, `get_multiple()`

### 2. Utils Package (`src/utils/`)

#### `ngsi_ld.py` - NGSI-LD Transformers
- `transform_camera_to_ngsi_ld()`: Camera data → NGSI-LD format
- `transform_incident_to_ngsi_ld()`: Incident data → NGSI-LD format
- `transform_zabbix_webhook_to_incident()`: Zabbix webhook → Incident structure
- `create_ngsi_ld_property()`: Helper for Property objects
- `create_ngsi_ld_relationship()`: Helper for Relationship objects

**NGSI-LD Compliance**: Implements ETSI CIM NGSI-LD v1.7.1 standard

### 3. Tests (`tests/`)

#### `test_database.py`
Comprehensive test suite covering:
- Database connection and health check
- All DAO class operations
- NGSI-LD transformations
- Error handling and edge cases

**Run tests**:
```bash
python3 /home/sysadmin/2025/aismc/aws-aiops/dev/6.greengrass_core/edge-database/tests/test_database.py
```

### 4. Scripts (`scripts/`)

#### `verify_dao.sh`
Deployment verification script that checks:
- Python3 availability
- Database file existence and permissions
- DAO Layer file deployment
- Python import functionality
- Database connectivity
- Basic DAO operations

**Run verification**:
```bash
/greengrass/v2/scripts/verify_dao.sh
```

## Deployment

### Via Terraform (Recommended)

```bash
cd /home/sysadmin/2025/aismc/aws-aiops/dev/6.greengrass_core

# Validate configuration
terraform validate

# Plan deployment
terraform plan -target=null_resource.verify_dao_deployment -out=tfplan-dao

# Review plan
terraform show tfplan-dao

# Apply deployment
terraform apply tfplan-dao
```

### Terraform Resources

The deployment creates:
- Directory structure at `/greengrass/v2/components/common/`
- Database package files (3 files)
- Utils package files (2 files)
- Verification script at `/greengrass/v2/scripts/verify_dao.sh`

**File Change Detection**: All resources have MD5 triggers for automatic redeployment when source files change.

## File Structure

```
/greengrass/v2/components/common/
├── database/
│   ├── __init__.py          # Package initialization
│   ├── connection.py         # DatabaseManager (singleton)
│   └── dao.py                # All DAO classes
└── utils/
    ├── __init__.py          # Package initialization
    └── ngsi_ld.py            # NGSI-LD transformers
```

## Usage Examples

### Basic Database Operations

```python
import sys
sys.path.insert(0, '/greengrass/v2/components/common')

from database.connection import DatabaseManager
from database.dao import CameraDAO, ConfigurationDAO

# Initialize
db = DatabaseManager()
camera_dao = CameraDAO(db)
config_dao = ConfigurationDAO(db)

# Get configuration
site_id = config_dao.get('site_id')

# Query cameras
cameras = camera_dao.get_all(site_id=site_id, status='online')
print(f"Found {len(cameras)} online cameras")

# Update camera status
camera_dao.update_status('CAM-001', 'offline')
```

### NGSI-LD Transformation

```python
from utils.ngsi_ld import transform_camera_to_ngsi_ld

camera_data = {
    'camera_id': 'CAM-001',
    'ip_address': '192.168.1.100',
    'hostname': 'camera-001',
    'status': 'online'
}

ngsi_ld = transform_camera_to_ngsi_ld(camera_data, 'site-001')
# Returns NGSI-LD formatted entity with URN, properties, and relationships
```

## Dependencies

- Python 3.x (system installed)
- SQLite3 (built-in with Python)
- No external pip packages required

## Performance

- **Connection Pooling**: Singleton pattern reduces connection overhead
- **WAL Mode**: Enabled for concurrent read/write access
- **Batch Operations**: `batch_upsert()` supports bulk inserts (1000+ records)
- **Indexed Queries**: All foreign keys and common query fields indexed

## Security

- **File Permissions**: All files owned by `ggc_user:ggc_group`
- **Database Access**: Read/write permissions restricted
- **No Hardcoded Secrets**: Configurations stored in database
- **Parameterized Queries**: Protection against SQL injection

## Monitoring

### Health Check

```python
db = DatabaseManager()
health = db.health_check()

# Returns:
# {
#   'status': 'healthy',
#   'integrity': 'ok',
#   'database_path': '/var/greengrass/database/greengrass.db',
#   'cameras': 10,
#   'incidents': 5,
#   'pending_messages': 2
# }
```

### Sync Logs

```python
from database.dao import SyncLogDAO

sync_log_dao = SyncLogDAO(db)
recent_syncs = sync_log_dao.get_recent(sync_type='camera_registry', limit=10)

for sync in recent_syncs:
    print(f"{sync['sync_timestamp']}: {sync['status']} ({sync['records_synced']} records)")
```

## Troubleshooting

### Import Errors

```bash
# Check Python path
python3 -c "import sys; print('\n'.join(sys.path))"

# Test imports
python3 << 'EOF'
import sys
sys.path.insert(0, '/greengrass/v2/components/common')
from database.connection import DatabaseManager
print("✅ Import successful")
EOF
```

### Database Connection Issues

```bash
# Check database file
ls -lh /var/greengrass/database/greengrass.db

# Check permissions
sudo -u ggc_user sqlite3 /var/greengrass/database/greengrass.db "SELECT COUNT(*) FROM cameras;"

# Check integrity
sqlite3 /var/greengrass/database/greengrass.db "PRAGMA integrity_check;"
```

### Permission Errors

```bash
# Fix DAO Layer permissions
sudo chown -R ggc_user:ggc_group /greengrass/v2/components/common
sudo chmod -R 755 /greengrass/v2/components/common
sudo chmod 644 /greengrass/v2/components/common/database/*.py
sudo chmod 644 /greengrass/v2/components/common/utils/*.py
```

## Next Steps

After successful deployment:

1. ✅ Run comprehensive test suite
2. ⏭️ Proceed with **Priority 2: Zabbix Configuration**
3. ⏭️ Develop custom Greengrass components that use this DAO layer

## References

- [SQLite Documentation](https://www.sqlite.org/docs.html)
- [ETSI NGSI-LD Specification](https://www.etsi.org/deliver/etsi_gs/CIM/001_099/009/01.07.01_60/gs_CIM009v010701p.pdf)
- [AWS IoT Greengrass Developer Guide](https://docs.aws.amazon.com/greengrass/v2/developerguide/)

## Changelog

### Version 1.0.0 (2026-01-01)
- Initial implementation
- DatabaseManager with singleton pattern
- 5 DAO classes (Camera, Incident, MessageQueue, SyncLog, Configuration)
- NGSI-LD transformation utilities
- Comprehensive test suite
- Terraform-managed deployment
