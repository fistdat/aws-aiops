# AWS IoT Infrastructure Deployment Report

**Deployment Date**: 2025-12-31
**AWS Region**: ap-southeast-1 (Singapore)
**AWS Account**: 061100493617
**Environment**: dev
**Project**: AIOps-IoC (AI Smart Monitoring Camera)

---

## Architecture Overview

### Data Flow
```
Camera Offline → Zabbix Monitoring → Greengrass Core → AWS IoT Core → DynamoDB → Grafana/SNS
```

### Architecture Diagram

```mermaid
graph TB
    subgraph "Edge Layer - Localhost"
        Cameras[IP Cameras<br/>192.168.x.x]
        Zabbix[Zabbix Monitoring<br/>localhost:10051]

        subgraph "Greengrass Core - GreengrassCore-site001-hanoi"
            GGNucleus[Greengrass Nucleus v2.16.0]
            GGComponent1[Zabbix Event Subscriber]
            GGComponent2[Incident Message Forwarder]
            GGShadow[Shadow Manager]
            LocalDB[(SQLite Database<br/>Incidents & Queue)]
        end
    end

    subgraph "AWS Cloud - ap-southeast-1"
        subgraph "IoT Core Services"
            ThingGroups[Thing Groups<br/>Vietnam → Hanoi-Site-001]
            Thing[Thing: GreengrassCore-site001-hanoi]
            IoTPolicy[IoT Policy<br/>greengrass-core-policy]
            IoTRules[IoT Rules Engine<br/>3 Active Rules]
        end

        subgraph "Data Processing Layer"
            Rule1[incidents_to_dynamodb]
            Rule2[registry_to_dynamodb]
            Rule3[critical_alerts_to_sns]
        end

        subgraph "Data Storage Layer"
            DDB1[(DynamoDB<br/>device-registry)]
            DDB2[(DynamoDB<br/>camera-incidents)]
        end

        subgraph "Notification Layer"
            SNS1[SNS Topic<br/>Critical Alerts]
            SNS2[SNS Topic<br/>Warning Alerts]
            SNS3[SNS Topic<br/>Operational]
            Email[Email Subscription<br/>aiops-alerts@aismc.vn]
        end

        subgraph "API Layer"
            APIGW[API Gateway REST API<br/>1rxrf4pq8j]
            Lambda1[Lambda: get_cameras]
            Lambda2[Lambda: get_incidents]
        end

        subgraph "Monitoring Layer"
            CW1[CloudWatch Logs<br/>IoT Rules Errors]
            CW2[CloudWatch Logs<br/>Lambda Functions]
            CW3[CloudWatch Logs<br/>API Gateway]
        end

        subgraph "IAM & Security"
            IAM1[IoT Core Service Role]
            IAM2[Lambda Execution Roles]
            IAM3[API Gateway Role]
        end

        subgraph "State Management"
            S3[S3 Bucket<br/>Terraform State]
            DDBLock[(DynamoDB<br/>State Lock)]
        end
    end

    subgraph "Visualization Layer"
        Grafana[Grafana Dashboard<br/>Localhost/Cloud]
    end

    %% Edge Layer Flow
    Cameras -->|ICMP Ping<br/>SNMP| Zabbix
    Zabbix -->|Webhook/API<br/>Camera Offline Event| GGComponent1
    GGComponent1 -->|Store| LocalDB
    GGComponent1 -->|Transform to<br/>NGSI-LD| GGComponent2
    GGComponent2 -->|MQTT/TLS<br/>cameras/site-001/incidents| Thing

    %% Cloud Flow
    Thing --> ThingGroups
    ThingGroups -->|Topic: cameras/+/incidents| Rule1
    ThingGroups -->|Topic: cameras/+/registry| Rule2
    ThingGroups -->|Topic: cameras/+/incidents<br/>Filter: priority=critical| Rule3

    Rule1 -->|Write| DDB2
    Rule2 -->|Write| DDB1
    Rule3 -->|Publish| SNS1

    SNS1 -->|Email Alert| Email

    IoTRules -->|Errors| CW1

    APIGW -->|GET /cameras| Lambda1
    APIGW -->|GET /incidents| Lambda2
    Lambda1 -->|Query| DDB1
    Lambda2 -->|Query| DDB2
    Lambda1 -->|Logs| CW2
    Lambda2 -->|Logs| CW2
    APIGW -->|Logs| CW3

    %% Grafana Integration
    Grafana -->|Query API| APIGW
    Grafana -->|Direct Query| DDB1
    Grafana -->|Direct Query| DDB2

    IAM1 -.->|Authorize| IoTRules
    IAM2 -.->|Authorize| Lambda1
    IAM2 -.->|Authorize| Lambda2
    IAM3 -.->|Authorize| APIGW

    %% Styling
    style Zabbix fill:#DC382D
    style GGNucleus fill:#7AA116
    style GGComponent1 fill:#7AA116
    style GGComponent2 fill:#7AA116
    style LocalDB fill:#FFD700
    style Thing fill:#FF9900
    style ThingGroups fill:#FF9900
    style IoTRules fill:#FF9900
    style DDB1 fill:#3B48CC
    style DDB2 fill:#3B48CC
    style SNS1 fill:#FF4F8B
    style APIGW fill:#FF4F8B
    style Lambda1 fill:#FF9900
    style Lambda2 fill:#FF9900
    style Grafana fill:#F46800
    style S3 fill:#569A31
```

---

## Deployment Summary

### Overall Status
- **Total Resources Deployed**: 60+ resources
- **Deployment Status**: ✅ Successful (9/10 components)
- **Validation Score**: 90%
- **Infrastructure as Code**: Terraform v1.14.3

### Components Deployed

| Component | Status | Resources | Details |
|-----------|--------|-----------|---------|
| S3 Backend | ✅ Deployed | 4 | State management with DynamoDB locking |
| IAM Roles | ✅ Deployed | 17 | Service roles for IoT, Lambda, API Gateway |
| IoT Core | ✅ Deployed | 12 | Thing Groups, Policies, Things |
| **Greengrass Core** | ✅ **Connected** | 1 Thing | **GreengrassCore-site001-hanoi** (v2.16.0) |
| Data Layer | ✅ Deployed | 2 | DynamoDB tables (no VPC required) |
| IoT Rules | ✅ Deployed | 8 | 3 Rules, 3 SNS Topics, 1 Subscription |
| API Gateway | ✅ Deployed | 25 | REST API with 2 Lambda functions |
| **Edge Monitoring** | ⏭️ **To Deploy** | - | **Zabbix Integration + Custom Components** |
| **Visualization** | ⏭️ **To Deploy** | - | **Grafana Dashboard** |
| Networking | ⏸️ Not Deployed | 0 | VPC not required for serverless architecture |
| Timestream | ⚠️ Skipped | 0 | Not supported in ap-southeast-1 |

---

## Infrastructure Details

### 1. Terraform State Management

**S3 Backend**
- **Bucket**: `aismc-platform-terraformstatefile-20251101-061100493617`
- **Region**: ap-southeast-1
- **Versioning**: Enabled
- **Encryption**: Enabled

**State Files**
```
aismc-dev/0.iam_assume_role_terraform/terraform.tfstate
aismc-dev/3.data_layer/terraform.tfstate
```

### 2. IAM Roles & Policies

**Created Roles** (17 resources)
1. **IoT Core Service Role**
   - ARN: `arn:aws:iam::061100493617:role/aismc-dev-iot-core-service-role`
   - Purpose: IoT Rules actions (DynamoDB, SNS, CloudWatch)

2. **Greengrass Core Role**
   - ARN: `arn:aws:iam::061100493617:role/aismc-dev-greengrass-core-role`
   - Purpose: Greengrass device operations

3. **Lambda Execution Roles**
   - ARN: `arn:aws:iam::061100493617:role/aismc-dev-iot-lambda-role`
   - Purpose: Lambda function execution with DynamoDB access

4. **API Gateway Service Role**
   - ARN: `arn:aws:iam::061100493617:role/aismc-dev-api-gateway-role`
   - Purpose: API Gateway to Lambda invocation

5. **API Gateway CloudWatch Role**
   - ARN: `arn:aws:iam::061100493617:role/aismc-dev-apigateway-cloudwatch-role`
   - Purpose: API Gateway logging to CloudWatch

### 3. IoT Core Configuration

**Thing Groups Hierarchy** (Hierarchical structure)
```
Vietnam (Root)
└── Hanoi-Site-001 (Child)
```

**IoT Policies**
- **greengrass-core-policy**
  - Permissions: Connect, Publish, Subscribe, Receive
  - Resources: All IoT resources (for development)

**MQTT Topics**
- `cameras/+/incidents` - Camera incident events
- `cameras/+/registry` - Device registration updates
- `cameras/+/metrics` - Device metrics (future use)

**IoT Things**
- **GreengrassCore-site001-hanoi**
  - ARN: `arn:aws:iot:ap-southeast-1:061100493617:thing/GreengrassCore-site001-hanoi`
  - Thing Type: GreengrassCoreDevice
  - Thing Group: Hanoi-Site-001
  - Certificate: Attached and Active
  - Status: ✅ Connected to AWS IoT Core
  - Region: ap-southeast-1

### 4. Edge Layer (Greengrass + Zabbix)

**AWS IoT Greengrass Core v2**
- **Thing Name**: GreengrassCore-site001-hanoi
- **Nucleus Version**: v2.16.0 (Latest)
- **Installation Path**: /greengrass/v2
- **Status**: ✅ RUNNING
- **Connection**: Successfully connected to AWS IoT Core ap-southeast-1
- **Endpoint**: `a3th3uw82ywkax-ats.iot.ap-southeast-1.amazonaws.com`

**Deployed Greengrass Components**
1. ✅ aws.greengrass.Nucleus v2.16.0 (FINISHED)
2. ✅ aws.greengrass.Cli v2.16.0 (RUNNING)
3. ✅ aws.greengrass.ShadowManager (RUNNING)
4. ✅ UpdateSystemPolicyService (RUNNING)
5. ✅ TelemetryAgent (RUNNING)
6. ✅ DeploymentService (RUNNING)
7. ✅ FleetStatusService (RUNNING)

**Custom Components (To Be Deployed)**
- ⏭️ **com.aismc.ZabbixEventSubscriber** v1.0.0
  - Purpose: Subscribe to Zabbix webhook events
  - Input: Zabbix problem/recovery notifications (real-time)
  - Output: Local SQLite storage + MQTT publish
  - Status: Ready to deploy

- ⏭️ **com.aismc.IncidentMessageForwarder** v1.0.0
  - Purpose: Transform and forward incidents to AWS IoT Core
  - Input: Local SQLite incidents queue
  - Output: MQTT messages to topic `cameras/site-001/incidents`
  - Format: NGSI-LD compliant

- ⏭️ **com.aismc.ZabbixHostRegistrySync** v1.0.0
  - Purpose: Sync ALL hosts metadata from Zabbix (incremental sync)
  - Scope: All host groups and all hosts (cameras, servers, network devices, etc.)
  - Input: Zabbix API (hostgroup.get + host.get with timestamps)
  - Schedule: Configurable via configuration table (default: daily at 2:00 AM)
  - Sync Strategy:
    - **Incremental Sync**: Only fetch hosts modified since last sync
    - **Change Detection**: Compare with last_sync timestamp in configuration
    - **Delta Processing**: New hosts, updated hosts, deleted hosts
  - Output:
    - Local SQLite storage (devices table - generalized from cameras)
    - Device Shadow update with metadata
    - Sync statistics (total, new, updated, deleted)
  - Configuration:
    - sync_schedule: Cron expression (default: "0 2 * * *")
    - sync_enabled: Boolean (true/false)
    - last_sync_timestamp: ISO8601 timestamp
    - incremental_sync: Boolean (true for delta, false for full sync)

**Local Data Storage**
- **SQLite Database**: /var/greengrass/database/greengrass.db
- **Tables**:
  - cameras (camera-specific registry - subset of devices)
  - devices (ALL host registry from Zabbix - generalized table)
  - host_groups (Zabbix host groups metadata)
  - incidents (offline/online events)
  - message_queue (outbound messages)
  - sync_log (synchronization history with checksums)
  - configuration (component settings including sync schedule)

**Zabbix Monitoring Server**
- **Host**: localhost
- **Version**: To be confirmed
- **API Endpoint**: http://localhost/zabbix/api_jsonrpc.php
- **Monitoring Method**: ICMP Ping + SNMP (for IP cameras)
- **Trigger**: Camera offline detection
- **Integration**: Webhook → Greengrass Component

**Data Flow Summary**
```
1. Real-time Incident Flow (Webhook-based):
   Device Offline → Zabbix Detection → Webhook → ZabbixEventSubscriber
                                                            ↓
                                                  Store SQLite + MQTT
                                                            ↓
                                              IncidentMessageForwarder
                                                            ↓
                                        AWS IoT Core → DynamoDB → SNS Alert

2. Scheduled Metadata Sync Flow (API-based, Incremental):
   Zabbix API (host groups + hosts) → ZabbixHostRegistrySync
                                                ↓
                                    Compare with last_sync timestamp
                                                ↓
                                    Fetch only changed/new hosts
                                                ↓
                            Store SQLite (devices + host_groups tables)
                                                ↓
                                    Update Device Shadow → DynamoDB
                                                ↓
                            Log sync statistics (total, new, updated, deleted)

3. Configuration Management:
   Configuration table stores:
   - last_sync_timestamp: Track incremental sync
   - sync_schedule: Cron expression for sync frequency
   - sync_enabled: Enable/disable scheduled sync
   - total_devices: Current total device count

4. Change Detection Logic:
   - Query: host.get with filter lastchange >= last_sync_timestamp
   - Compare checksum (MD5 of host metadata)
   - If no changes detected → Skip sync, log "no changes"
   - If changes detected → Process delta only

5. Alerting & Visualization:
   DynamoDB → API Gateway → Lambda → Grafana Dashboard
   Critical incidents → SNS → Email alerts
```

### 5. Data Storage Layer

**DynamoDB Tables** (Serverless, no VPC required)

1. **device-registry**
   - Purpose: IoT device registry and metadata
   - Hash Key: deviceId (String)
   - Billing: PAY_PER_REQUEST
   - Point-in-time Recovery: Enabled

2. **camera-incidents**
   - Purpose: Camera incident logging
   - Hash Key: incidentId (String)
   - Range Key: timestamp (Number)
   - Billing: PAY_PER_REQUEST
   - Point-in-time Recovery: Enabled
   - GSI: siteId-timestamp-index

**Timestream Database** (Skipped)
- Status: ⚠️ Not deployed
- Reason: Timestream IoT integration not supported in ap-southeast-1
- Alternative: DynamoDB for time-series data

### 5. IoT Rules Engine

**Active Rules** (3 rules)

1. **aismc_dev_incidents_to_dynamodb**
   - SQL: `SELECT * FROM 'cameras/+/incidents'`
   - Action: DynamoDB PutItem → camera-incidents
   - Error Handling: CloudWatch Logs

2. **aismc_dev_registry_to_dynamodb**
   - SQL: `SELECT * FROM 'cameras/+/registry'`
   - Action: DynamoDB PutItem → device-registry
   - Error Handling: CloudWatch Logs

3. **aismc_dev_critical_alerts**
   - SQL: `SELECT * FROM 'cameras/+/incidents' WHERE incident_type = 'camera_offline' AND priority = 'critical'`
   - Action: SNS Publish → critical-alerts topic
   - Error Handling: CloudWatch Logs

**SNS Topics** (3 topics)

1. **aismc-dev-critical-alerts**
   - ARN: `arn:aws:sns:ap-southeast-1:061100493617:aismc-dev-critical-alerts`
   - Purpose: Critical incidents requiring immediate attention
   - Subscription: Email → aiops-alerts@aismc.vn

2. **aismc-dev-warning-alerts**
   - ARN: `arn:aws:sns:ap-southeast-1:061100493617:aismc-dev-warning-alerts`
   - Purpose: Warning-level incidents
   - Subscription: Not configured (future use)

3. **aismc-dev-operational-notifications**
   - ARN: `arn:aws:sns:ap-southeast-1:061100493617:aismc-dev-operational-notifications`
   - Purpose: General operational notifications
   - Subscription: Not configured (future use)

**CloudWatch Logging**
- Log Group: `/aws/iot/rules/aismc-dev/errors`
- Retention: 30 days

### 6. API Gateway & Lambda

**API Gateway REST API**
- **API ID**: 1rxrf4pq8j
- **ARN**: `arn:aws:apigateway:ap-southeast-1::/restapis/1rxrf4pq8j`
- **Endpoint Type**: REGIONAL
- **Stage**: dev

**API Endpoints**
- Base URL: `https://1rxrf4pq8j.execute-api.ap-southeast-1.amazonaws.com/dev`
- GET `/cameras` → Lambda: get_cameras → DynamoDB: device-registry
- GET `/incidents` → Lambda: get_incidents → DynamoDB: camera-incidents
- `/metrics` - Reserved for future use

**Lambda Functions** (2 functions)

1. **aismc-dev-get-cameras**
   - ARN: `arn:aws:lambda:ap-southeast-1:061100493617:function:aismc-dev-get-cameras`
   - Runtime: Python 3.x
   - Purpose: Query device registry from DynamoDB
   - CloudWatch Logs: `/aws/lambda/aismc-dev-get-cameras`

2. **aismc-dev-get-incidents**
   - ARN: `arn:aws:lambda:ap-southeast-1:061100493617:function:aismc-dev-get-incidents`
   - Runtime: Python 3.x
   - Purpose: Query incidents from DynamoDB
   - CloudWatch Logs: `/aws/lambda/aismc-dev-get-incidents`

**CORS Configuration**
- Enabled for `/cameras` endpoint
- Allowed Methods: GET, OPTIONS
- Allowed Headers: Content-Type, X-Amz-Date, Authorization, X-Api-Key, X-Amz-Security-Token
- Allowed Origin: * (for development)

**API Gateway Logging**
- Log Group: `/aws/apigateway/aismc-dev`
- Retention: 30 days
- Logging Level: INFO
- Metrics: Enabled

### 7. Monitoring & Logging

**CloudWatch Log Groups** (4 groups)
1. `/aws/iot/rules/aismc-dev/errors` - IoT Rules errors
2. `/aws/lambda/aismc-dev-get-cameras` - Lambda function logs
3. `/aws/lambda/aismc-dev-get-incidents` - Lambda function logs
4. `/aws/apigateway/aismc-dev` - API Gateway execution logs

**Metrics & Monitoring**
- API Gateway metrics enabled
- Lambda function metrics enabled
- IoT Rules error tracking enabled

### 8. Network Architecture

**Note**: This is a serverless architecture without VPC deployment.

- **No VPC Required**: All services (DynamoDB, Lambda, API Gateway, IoT Core) are fully managed AWS services
- **Public Accessibility**: API Gateway provides public HTTPS endpoints
- **Security**: IAM roles, API authentication (to be implemented), MQTT TLS for IoT devices
- **Scalability**: Auto-scaling managed by AWS services

**Network Module Status**
- Module exists at: `dev/1.networking`
- Deployment Status: ⏸️ Not deployed (not required for current architecture)
- Purpose: Reserved for future use if VPC-based resources are needed

---

## Validation Results

**Infrastructure Validation Script**: `./scripts/1. AWS Infrastructure Setup/validate-infrastructure.sh`

```
==================================
Infrastructure Validation
==================================

✓ Thing Group 'Vietnam' exists
✓ Thing Group 'Hanoi-Site-001' exists
✓ IoT Policy 'greengrass-core-policy' exists
✓ DynamoDB table 'device-registry' exists
✓ DynamoDB table 'camera-incidents' exists
✗ Timestream database 'iot-metrics' not found (EXPECTED - not supported)
✓ IoT Rules configured (count: 3)
✓ SNS topics configured (count: 3)
✓ API Gateway deployed (ID: 1rxrf4pq8j)
✓ API Gateway endpoint accessible (HTTP 200)
✓ Lambda functions deployed (count: 2)

Validation Score: 9/10 ✅
```

**Component Health**
- IoT Core: ✅ Healthy
- DynamoDB: ✅ Healthy
- IoT Rules: ✅ Healthy (3/3 active)
- SNS: ✅ Healthy (3 topics, 1 subscription)
- API Gateway: ✅ Healthy (endpoint accessible)
- Lambda: ✅ Healthy (2 functions deployed)

---

## Deployment Issues & Resolutions

### Issues Encountered

1. **S3 Bucket Naming Conflict**
   - Error: Bucket name not unique globally
   - Resolution: Added account ID suffix: `aismc-platform-terraformstatefile-20251101-061100493617`

2. **Duplicate Terraform Definitions**
   - Error: Variables and outputs defined in both main.tf and separate files
   - Resolution: Removed all variable/output definitions from main.tf in modules:
     - `_module/aws/iot/iot_policy/main.tf`
     - `_module/aws/iot/thing_group/main.tf`
     - `_module/aws/data/dynamodb/main.tf`

3. **Thing Group Parent-Child Relationship**
   - Error: Incorrect use of `aws_iot_thing_group_membership` for group-to-group
   - Resolution: Used `parent_group_name` attribute directly in `aws_iot_thing_group`

4. **Remote State Bucket References**
   - Error: References to non-existent bucket `aismc-nonprod-terraform-state`
   - Resolution: Updated all remote state references to correct bucket name in:
     - `dev/4.iot_rules/main.tf`
     - `dev/5.api_gateway/lambda.tf`

5. **API Gateway CloudWatch Logging**
   - Error: CloudWatch Logs role ARN not set in account settings
   - Resolution: Created IAM role and configured account-level settings:
     - Created `aismc-dev-apigateway-cloudwatch-role`
     - Attached `AmazonAPIGatewayPushToCloudWatchLogs` policy
     - Set via `aws_api_gateway_account` resource

6. **Timestream Regional Support**
   - Error: Timestream IoT integration not supported in ap-southeast-1
   - Resolution: Commented out Timestream-related resources:
     - IoT Rule: `metrics_to_timestream`
     - Updated outputs to exclude Timestream

7. **Data Layer State Migration**
   - Error: Local state needed migration to S3 backend
   - Resolution: Enabled S3 backend and migrated state:
     ```bash
     terraform init -migrate-state
     ```

---

## Security Configuration

### Authentication & Authorization

**Current State (Development)**
- API Gateway: No authentication (development mode)
- IoT Core: TLS certificates required
- IAM: Least privilege roles for service-to-service communication

**Recommended for Production**
- [ ] Enable API Gateway authentication (API Keys, Cognito, or Lambda Authorizer)
- [ ] Implement IoT device certificates management
- [ ] Enable AWS WAF for API Gateway
- [ ] Configure VPC endpoints for private API access
- [ ] Enable CloudTrail for audit logging
- [ ] Configure AWS Config for compliance monitoring

### IAM Policies

All IAM roles follow least privilege principle:
- IoT Core role: Limited to DynamoDB, SNS, CloudWatch actions
- Lambda roles: Limited to DynamoDB read/write and CloudWatch logs
- API Gateway role: Limited to Lambda invocation

### Data Encryption

- **At Rest**:
  - DynamoDB: Encrypted with AWS managed keys
  - S3 State: Encrypted with AWS managed keys
  - CloudWatch Logs: Encrypted

- **In Transit**:
  - IoT Core: MQTT over TLS 1.2+
  - API Gateway: HTTPS only
  - DynamoDB: HTTPS API calls

---

## Cost Estimation

### Monthly Cost Breakdown (Development Environment)

| Service | Usage | Estimated Monthly Cost |
|---------|-------|----------------------|
| IoT Core | 100 devices, 1M messages/month | ~$5 |
| DynamoDB | On-demand, 1M reads, 500K writes | ~$1.50 |
| Lambda | 100K invocations, 128MB, 1s avg | ~$0.20 |
| API Gateway | 100K requests | ~$0.35 |
| SNS | 1K email notifications | ~$0.50 |
| CloudWatch Logs | 5GB ingestion, 30-day retention | ~$2.50 |
| S3 (State) | Minimal storage | ~$0.10 |
| **Total Estimated** | | **~$10.15/month** |

**Notes**:
- Costs based on low development usage
- Production costs will scale with actual usage
- Free tier eligible for first 12 months (Lambda, DynamoDB, API Gateway)

---

## Next Steps

### ✅ Phase 1: AWS Cloud Infrastructure (COMPLETED)
1. ✅ S3 Backend & Terraform State Management
2. ✅ IAM Roles & Policies
3. ✅ AWS IoT Core (Thing Groups, Policies, Things)
4. ✅ DynamoDB Tables (device-registry, camera-incidents)
5. ✅ IoT Rules Engine (3 rules active)
6. ✅ SNS Topics & Email Subscriptions
7. ✅ API Gateway + Lambda Functions
8. ✅ CloudWatch Logging & Monitoring
9. ✅ Greengrass Core Installation & Connection
10. ✅ Infrastructure Validation (9/10 components)

### ⏭️ Phase 2: Edge Layer Integration (NEXT - IN PROGRESS)

**Priority 1: Database & Schema Setup**
1. ⏭️ Create SQLite database schema
   - Location: `/var/greengrass/database/greengrass.db`
   - Tables: cameras, incidents, message_queue, sync_log, configuration
   - Indexes: Optimized for query performance
   - WAL mode: Enabled for concurrent access

2. ⏭️ Implement Database DAO Layer (Python)
   - DatabaseManager: Connection pooling
   - CameraDAO: CRUD operations for camera registry
   - IncidentDAO: Incident management with sync status
   - MessageQueueDAO: Retry queue management
   - SyncLogDAO: Audit trail for synchronization

**Priority 2: Zabbix Integration**
3. ⏭️ Configure Zabbix Server
   - Verify Zabbix installation on localhost
   - Configure host groups for IP cameras
   - Setup ICMP ping monitoring
   - Create triggers for camera offline detection
   - Configure webhook media type for Greengrass

4. ⏭️ Test Zabbix → Greengrass Communication
   - Webhook endpoint: http://localhost:8080/zabbix/events
   - Webhook payload format: JSON with problem/recovery data
   - Authentication: API token or basic auth
   - Test offline/online event generation

**Priority 3: Custom Greengrass Components Development**
5. ⏭️ Develop com.aismc.ZabbixEventSubscriber v1.0.0
   - HTTP server to receive Zabbix webhooks
   - Parse Zabbix problem/recovery events
   - Extract camera_id, incident_type, timestamp
   - Store in SQLite incidents table
   - Publish to local MQTT topic for forwarding

6. ⏭️ Develop com.aismc.IncidentMessageForwarder v1.0.0
   - Subscribe to local incidents topic
   - Transform to NGSI-LD format
   - Dual storage: SQLite + Stream Manager
   - Publish to AWS IoT Core topic `cameras/site-001/incidents`
   - Retry logic for offline scenarios

7. ⏭️ Develop com.aismc.CameraRegistrySync v1.0.0
   - Fetch camera list from Zabbix API
   - Transform to NGSI-LD format
   - Store in SQLite cameras table
   - Update Device Shadow
   - Schedule: Daily at 2:00 AM (cron)

**Priority 4: Component Deployment**
8. ⏭️ Package and Upload Components
   - Create component recipes (recipe.yaml)
   - Upload artifacts to S3 bucket
   - Create component versions via AWS CLI

9. ⏭️ Deploy Components to Greengrass Core
   - Create deployment configuration
   - Deploy to Thing: GreengrassCore-site001-hanoi
   - Verify component status (RUNNING)
   - Monitor logs for errors

**Priority 5: Testing & Validation**
10. ⏭️ End-to-End Testing
    - Simulate camera offline event in Zabbix
    - Verify Greengrass component receives event
    - Verify SQLite storage
    - Verify MQTT publish to AWS IoT Core
    - Verify DynamoDB record creation
    - Verify SNS email alert (for critical)

11. ⏭️ Offline Operation Testing
    - Disconnect from internet
    - Generate 100+ offline events
    - Verify local SQLite queue
    - Restore connectivity
    - Verify auto-sync to cloud

### ⏭️ Phase 3: Visualization & Dashboard (FUTURE)

12. ⏭️ Grafana Dashboard Setup
    - Install Grafana (localhost or cloud)
    - Configure AWS DynamoDB data source
    - Configure API Gateway data source
    - Create dashboards:
      - Real-time camera status
      - Incident timeline
      - Site-level statistics
      - Alert history

13. ⏭️ Dashboard Panels
    - Camera Status Map (online/offline by location)
    - Incident Count by Type (pie chart)
    - Timeline of Incidents (time series)
    - Top 10 Problematic Cameras (table)
    - Mean Time to Recovery (MTTR) metric

### ⏭️ Phase 4: Production Hardening (FUTURE)

14. ⏭️ Security Enhancements
    - Enable API Gateway authentication (Cognito or API Keys)
    - Configure AWS WAF for API protection
    - Implement certificate rotation for Greengrass
    - Enable CloudTrail audit logging

15. ⏭️ Monitoring & Alerting
    - CloudWatch dashboards for Greengrass components
    - Alarms for component failures
    - Alarms for high incident rates
    - X-Ray tracing for debugging

16. ⏭️ Backup & Disaster Recovery
    - DynamoDB point-in-time recovery (already enabled)
    - SQLite database backup automation
    - Greengrass configuration backup
    - Recovery runbooks

### Testing Plan (Phase 2)

**1. Unit Testing**
- [ ] Database DAO layer tests
- [ ] NGSI-LD transformer tests
- [ ] Zabbix webhook parser tests

**2. Integration Testing**
- [ ] Zabbix → Greengrass webhook flow
- [ ] Greengrass → AWS IoT Core MQTT flow
- [ ] IoT Rules → DynamoDB → SNS flow
- [ ] API Gateway → Lambda → DynamoDB query

**3. End-to-End Testing**
```bash
# Test Scenario: Camera Offline Detection
1. Disconnect camera from network
2. Wait for Zabbix trigger (typically 30s-60s)
3. Zabbix sends webhook to Greengrass
4. Greengrass processes event and forwards to AWS
5. AWS IoT Core routes to DynamoDB
6. Critical incident triggers SNS email
7. Grafana displays incident in real-time
8. Reconnect camera
9. Zabbix sends recovery webhook
10. System updates incident status to resolved
```

**4. Performance Testing**
- [ ] Load test with 1000 cameras
- [ ] Simulate 100 concurrent offline events
- [ ] Measure end-to-end latency (Zabbix → Email)
- [ ] Verify no message loss during high load

**5. Resilience Testing**
- [ ] Offline operation (24 hours without internet)
- [ ] Component restart recovery
- [ ] Database corruption recovery
- [ ] AWS service outage handling

---

## Terraform Modules Structure

```
aiops-01/
├── _module/aws/                    # Reusable Terraform modules
│   ├── data/
│   │   └── dynamodb/              # DynamoDB table module
│   ├── iot/
│   │   ├── iot_policy/            # IoT policy module
│   │   └── thing_group/           # Thing group module
│   └── networking/
│       └── vpc/                   # VPC module (not deployed)
├── dev/                           # Development environment
│   ├── 0.iam_assume_role_terraform/  # ✅ IAM roles
│   ├── 1.networking/              # ⏸️ VPC (not deployed)
│   ├── 2.iot_core/                # ✅ IoT Core
│   ├── 3.data_layer/              # ✅ DynamoDB
│   ├── 4.iot_rules/               # ✅ IoT Rules Engine
│   └── 5.api_gateway/             # ✅ API Gateway + Lambda
└── ops/                           # Operations
    └── 0.init_s3_backend/         # ✅ S3 Terraform state
```

---

## API Endpoints Reference

### Base URL
```
https://1rxrf4pq8j.execute-api.ap-southeast-1.amazonaws.com/dev
```

### Available Endpoints

#### GET /cameras
**Description**: Retrieve list of registered cameras/devices

**Request**:
```bash
curl -X GET https://1rxrf4pq8j.execute-api.ap-southeast-1.amazonaws.com/dev/cameras
```

**Response** (200 OK):
```json
{
  "devices": [
    {
      "deviceId": "camera-001",
      "siteId": "Hanoi-Site-001",
      "status": "online",
      "lastSeen": 1704067200
    }
  ]
}
```

#### GET /incidents
**Description**: Retrieve camera incidents

**Request**:
```bash
curl -X GET https://1rxrf4pq8j.execute-api.ap-southeast-1.amazonaws.com/dev/incidents
```

**Response** (200 OK):
```json
{
  "incidents": [
    {
      "incidentId": "inc-001",
      "deviceId": "camera-001",
      "incidentType": "camera_offline",
      "priority": "critical",
      "timestamp": 1704067200
    }
  ]
}
```

---

## MQTT Topics Reference

### Device Communication Topics

#### Incident Reporting
**Topic**: `cameras/{deviceId}/incidents`

**Payload Example**:
```json
{
  "deviceId": "camera-001",
  "incidentType": "camera_offline",
  "priority": "critical",
  "timestamp": 1704067200,
  "metadata": {
    "reason": "network_timeout",
    "lastFrameTime": 1704067150
  }
}
```

**IoT Rule**: Routes to DynamoDB (camera-incidents) and SNS (if critical)

#### Device Registry Updates
**Topic**: `cameras/{deviceId}/registry`

**Payload Example**:
```json
{
  "deviceId": "camera-001",
  "siteId": "Hanoi-Site-001",
  "status": "online",
  "firmwareVersion": "1.2.3",
  "ipAddress": "192.168.1.100",
  "timestamp": 1704067200
}
```

**IoT Rule**: Routes to DynamoDB (device-registry)

#### Device Metrics (Future Use)
**Topic**: `cameras/{deviceId}/metrics`

**Payload Example**:
```json
{
  "deviceId": "camera-001",
  "metrics": {
    "cpu_usage": 45.2,
    "memory_usage": 67.8,
    "network_latency": 23,
    "frame_rate": 30
  },
  "timestamp": 1704067200
}
```

**IoT Rule**: Not configured (Timestream not available)

---

## Contact & Support

**Project Team**:
- Email: aiops-alerts@aismc.vn
- AWS Account: 061100493617
- Region: ap-southeast-1

**Documentation**:
- Deployment Guide: `/claudedocs/Overview/DEPLOYMENT-STEP-BY-STEP.md`
- Architecture: This document
- Scripts: `/scripts/1. AWS Infrastructure Setup/`

---

## Appendix

### A. Terraform Commands Reference

```bash
# Initialize module
terraform init

# Validate configuration
terraform validate

# Plan deployment
terraform plan -out=tfplan

# Apply deployment
terraform apply tfplan

# Show current state
terraform show

# List resources
terraform state list

# View outputs
terraform output

# Destroy resources (careful!)
terraform destroy
```

### B. AWS CLI Commands Reference

```bash
# List IoT Thing Groups
aws iot list-thing-groups --region ap-southeast-1

# List IoT Policies
aws iot list-policies --region ap-southeast-1

# List IoT Rules
aws iot list-topic-rules --region ap-southeast-1

# List DynamoDB Tables
aws dynamodb list-tables --region ap-southeast-1

# List SNS Topics
aws sns list-topics --region ap-southeast-1

# Test API Gateway endpoint
curl https://1rxrf4pq8j.execute-api.ap-southeast-1.amazonaws.com/dev/cameras
```

### C. Troubleshooting Guide

**Issue**: API Gateway returns 403 Forbidden
- **Check**: API Gateway deployment stage is correct
- **Check**: Lambda permissions allow API Gateway invocation
- **Check**: CloudWatch logs for detailed error messages

**Issue**: IoT messages not appearing in DynamoDB
- **Check**: IoT Rule is enabled
- **Check**: IAM role has DynamoDB write permissions
- **Check**: CloudWatch logs `/aws/iot/rules/aismc-dev/errors` for errors
- **Check**: Message format matches rule SQL query

**Issue**: SNS notifications not received
- **Check**: Email subscription is confirmed
- **Check**: IoT Rule SQL query matches message content
- **Check**: IAM role has SNS publish permissions

---

**Document Version**: 1.0
**Last Updated**: 2025-12-31
**Generated by**: Claude Code (Terraform deployment automation)
