# Hướng Dẫn Terraform - Từ Cơ Bản Đến Triển Khai

## 📚 Mục Lục

1. [Terraform Là Gì?](#terraform-là-gì)
2. [Cấu Trúc Thư Mục Dự Án](#cấu-trúc-thư-mục-dự-án)
3. [Các File Terraform Cơ Bản](#các-file-terraform-cơ-bản)
4. [Module Là Gì?](#module-là-gì)
5. [Chi Tiết Các Module Trong Dự Án](#chi-tiết-các-module-trong-dự-án)
6. [Terraform Workflow](#terraform-workflow)
7. [Câu Lệnh Terraform Cơ Bản](#câu-lệnh-terraform-cơ-bản)

---

## Terraform Là Gì?

**Terraform** là công cụ **Infrastructure as Code (IaC)** - quản lý hạ tầng bằng code.

### Tại Sao Dùng Terraform?

❌ **Cách truyền thống** (Manual):
```
Bạn → AWS Console → Click, click, click → Tạo resources
Vấn đề:
- Mất thời gian
- Dễ sai
- Không lặp lại được
- Không biết ai đã tạo cái gì
```

✅ **Cách dùng Terraform**:
```
Bạn → Viết code (main.tf) → terraform apply → AWS tự động tạo resources
Ưu điểm:
- Tự động hóa
- Lặp lại được (dev, staging, prod)
- Có version control (Git)
- Biết rõ ai làm gì, khi nào
```

### Ví Dụ Đơn Giản

**Tạo S3 bucket bằng AWS Console**: 10 phút, 15 clicks

**Tạo S3 bucket bằng Terraform**:
```hcl
resource "aws_s3_bucket" "my_bucket" {
  bucket = "my-bucket-name"

  tags = {
    Name = "My bucket"
  }
}
```

Chạy: `terraform apply` → S3 bucket được tạo tự động!

---

## Cấu Trúc Thư Mục Dự Án

```
cluster-nonprod-iac-main/
│
├── ops/                    # Infrastructure cho operations (shared resources)
│   ├── 0.init_s3_backend/  # Tạo S3 để lưu Terraform state
│   └── 1.organization/     # Tạo AWS Organization (quản lý nhiều AWS accounts)
│
├── dev/                    # Development environment
│   ├── 0.iam_assume_role_terraform/  # Tạo IAM roles (quyền hạn)
│   ├── 1.networking/       # Tạo VPC, Subnets (network)
│   ├── 2.iot_core/         # Tạo IoT Core resources (Thing Groups, Policies)
│   ├── 3.data_layer/       # Tạo DynamoDB, Timestream (database)
│   ├── 4.iot_rules/        # Tạo IoT Rules Engine (routing messages)
│   └── 5.api_gateway/      # Tạo API Gateway, Lambda (API backend)
│
├── _module/                # Các module tái sử dụng được
│   └── aws/
│       ├── iot/            # Module cho IoT resources
│       │   ├── thing_group/
│       │   └── iot_policy/
│       └── data/           # Module cho data resources
│           └── dynamodb/
│
├── scripts/                # Automation scripts
│   ├── deploy-week1-2.sh
│   ├── validate-infrastructure.sh
│   ├── create-iot-certificate.sh
│   └── test-iot-message.sh
│
└── claudedocs/             # Documentation
    ├── TERRAFORM-GUIDE.md           # ← File này
    └── DEPLOYMENT-STEP-BY-STEP.md   # ← Hướng dẫn triển khai
```

### Phân Biệt `ops/` và `dev/`

**ops/** - Operations layer:
- Shared resources cho toàn bộ organization
- Ví dụ: S3 backend, AWS Organization
- Deploy 1 lần, dùng cho tất cả environments

**dev/** - Development environment:
- Resources riêng cho môi trường dev
- Sau này có thể tạo thêm `prod/` cho production
- Mỗi environment độc lập

---

## Các File Terraform Cơ Bản

Trong mỗi module Terraform, bạn sẽ thấy các file sau:

### 1. **main.tf** - File Chính

**Mục đích**: Chứa các **resources** chính mà module này tạo ra

**Ví dụ**:
```hcl
# Tạo một S3 bucket
resource "aws_s3_bucket" "my_bucket" {
  bucket = "aismc-dev-iot-certificates"

  tags = {
    Environment = "dev"
  }
}
```

**Giải thích**:
- `resource`: Keyword để khai báo tạo resource
- `"aws_s3_bucket"`: Loại resource (S3 bucket trên AWS)
- `"my_bucket"`: Tên để tham chiếu trong Terraform (tên local)
- `bucket = "..."`: Tham số của resource (tên thật của S3 bucket)

---

### 2. **variables.tf** - File Khai Báo Biến

**Mục đích**: Khai báo các **input variables** (tham số đầu vào)

**Ví dụ**:
```hcl
variable "environment" {
  description = "Environment name (dev, staging, prod)"
  type        = string
  default     = "dev"
}

variable "camera_count" {
  description = "Number of cameras at this site"
  type        = number
  default     = 15000
}
```

**Giải thích**:
- `description`: Mô tả biến này dùng để làm gì
- `type`: Kiểu dữ liệu (string, number, bool, list, map, ...)
- `default`: Giá trị mặc định (optional)

**Cách dùng biến**:
```hcl
resource "aws_s3_bucket" "my_bucket" {
  bucket = "aismc-${var.environment}-bucket"  # → "aismc-dev-bucket"

  tags = {
    Environment = var.environment  # → "dev"
  }
}
```

---

### 3. **locals.tf** - File Khai Báo Biến Local

**Mục đích**: Khai báo **local variables** (biến nội bộ, không nhận từ bên ngoài)

**Ví dụ**:
```hcl
locals {
  product_name = "aismc"
  environment  = "dev"

  # Tạo tags chung cho tất cả resources
  tags = {
    Environment = local.environment
    Product     = local.product_name
    ManagedBy   = "Terraform"
    Project     = "AIOps-IoC"
  }

  # Tạo tên có prefix
  bucket_name = "${local.product_name}-${local.environment}-certificates"
  # → "aismc-dev-certificates"
}
```

**Phân biệt `var` vs `local`**:

| | `var` (variables.tf) | `local` (locals.tf) |
|---|---|---|
| **Input** | Nhận từ bên ngoài | Tính toán nội bộ |
| **Sử dụng** | `var.environment` | `local.tags` |
| **Khi nào dùng** | Cần customize | Giá trị cố định, công thức |

---

### 4. **outputs.tf** - File Xuất Kết Quả

**Mục đích**: Xuất (export) thông tin sau khi tạo resources

**Ví dụ**:
```hcl
output "bucket_name" {
  description = "Name of the S3 bucket"
  value       = aws_s3_bucket.my_bucket.id
}

output "bucket_arn" {
  description = "ARN of the S3 bucket"
  value       = aws_s3_bucket.my_bucket.arn
}
```

**Cách xem outputs**:
```bash
terraform output                    # Xem tất cả outputs
terraform output bucket_name        # Xem 1 output cụ thể
terraform output -raw bucket_name   # Xem không có dấu ngoặc kép
```

**Output được dùng ở đâu?**
1. **Xem thông tin** sau khi deploy (ví dụ: API endpoint URL)
2. **Module khác sử dụng** (ví dụ: module B cần bucket_name từ module A)

---

### 5. **provider.tf** - File Cấu Hình Provider

**Mục đích**: Khai báo **provider** (AWS, Azure, GCP, ...) và cấu hình

**Ví dụ**:
```hcl
terraform {
  required_version = ">= 1.5.0"  # Terraform version tối thiểu

  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"  # AWS provider version 5.x
    }
  }

  # Cấu hình backend (lưu state ở đâu)
  backend "s3" {
    bucket         = "aismc-nonprod-terraform-state"
    key            = "dev/iot-core/terraform.tfstate"
    region         = "ap-southeast-1"
    encrypt        = true
    dynamodb_table = "terraform-state-lock"
  }
}

provider "aws" {
  region = "ap-southeast-1"  # Singapore region

  default_tags {
    tags = local.tags  # Apply tags cho TẤT CẢ resources
  }
}
```

**Giải thích**:
- `required_version`: Terraform CLI version
- `required_providers`: Các provider cần dùng
- `backend`: Nơi lưu trữ **terraform state** (file lưu trạng thái infrastructure)
- `provider "aws"`: Cấu hình AWS provider (region, credentials, ...)

---

### 6. **data.tf** - File Data Sources

**Mục đích**: Lấy thông tin từ resources **đã tồn tại**

**Ví dụ**:
```hcl
# Lấy thông tin AWS account hiện tại
data "aws_caller_identity" "current" {}

# Lấy thông tin AWS region hiện tại
data "aws_region" "current" {}

# Lấy thông tin IoT endpoint
data "aws_iot_endpoint" "data" {
  endpoint_type = "iot:Data-ATS"
}

# Sử dụng data
locals {
  account_id = data.aws_caller_identity.current.account_id
  region     = data.aws_region.current.name
  iot_endpoint = data.aws_iot_endpoint.data.endpoint_address
}
```

**Phân biệt `resource` vs `data`**:

| | `resource` | `data` |
|---|---|---|
| **Mục đích** | **TẠO** resource mới | **ĐỌC** resource đã có |
| **Ví dụ** | Tạo S3 bucket mới | Lấy thông tin VPC đã tồn tại |
| **Terraform quản lý** | Có | Không |

---

## Module Là Gì?

**Module** = một nhóm resources liên quan được đóng gói lại

### Tại Sao Dùng Module?

**Không dùng module** (lặp code):
```hcl
# Tạo Thing Group 1
resource "aws_iot_thing_group" "vietnam" {
  name = "Vietnam"
  properties {
    description = "Root Thing Group"
  }
}

# Tạo Thing Group 2 (lặp code y hệt)
resource "aws_iot_thing_group" "northern" {
  name = "Northern-Region"
  properties {
    description = "Northern Region"
  }
}

# Tạo Thing Group 3, 4, 5... (lặp mãi)
```

**Dùng module** (tái sử dụng):
```hcl
# Định nghĩa module 1 lần
module "vietnam_thing_group" {
  source = "../../_module/aws/iot/thing_group"

  thing_group_name = "Vietnam"
  description      = "Root Thing Group"
}

# Tái sử dụng module
module "northern_thing_group" {
  source = "../../_module/aws/iot/thing_group"

  thing_group_name = "Northern-Region"
  description      = "Northern Region"
}

# Dễ dàng tạo thêm bao nhiêu cũng được
```

### Cấu Trúc Module

```
_module/aws/iot/thing_group/
├── main.tf       # Định nghĩa resources
├── variables.tf  # Input parameters
└── outputs.tf    # Output values
```

**Module nhận input từ caller**:
```hcl
# Trong _module/aws/iot/thing_group/variables.tf
variable "thing_group_name" {
  type = string
}

variable "description" {
  type = string
}

# Trong _module/aws/iot/thing_group/main.tf
resource "aws_iot_thing_group" "this" {
  name = var.thing_group_name  # Nhận từ caller

  properties {
    description = var.description  # Nhận từ caller
  }
}
```

**Caller truyền input vào module**:
```hcl
module "vietnam_thing_group" {
  source = "../../_module/aws/iot/thing_group"

  # Truyền giá trị vào module
  thing_group_name = "Vietnam"
  description      = "Root Thing Group"
}
```

---

## Chi Tiết Các Module Trong Dự Án

### ops/0.init_s3_backend - S3 Backend Setup

**Mục đích**: Tạo S3 bucket để lưu **Terraform State**

**Terraform State là gì?**
- File JSON lưu trạng thái infrastructure hiện tại
- Ví dụ: Bạn đã tạo 5 S3 buckets, 3 DynamoDB tables → State file ghi nhớ
- Terraform dùng state để biết cần tạo/xóa/update cái gì

**Tại sao lưu state trên S3?**
- ✅ Shared: Team cùng xem state
- ✅ Locking: Tránh 2 người chạy terraform cùng lúc
- ✅ Versioning: Có thể rollback state
- ✅ Encryption: Bảo mật

**Files**:
```
ops/0.init_s3_backend/
├── s3.tf         # Tạo S3 bucket + DynamoDB table cho locking
├── locals.tf     # Biến local (bucket name, tags)
└── provider.tf   # AWS provider config
```

**Deploy thứ tự**: **LUÔN LUÔN deploy module này TRƯỚC TIÊN**

---

### ops/1.organization - AWS Organization

**Mục đích**: Tạo AWS Organization để quản lý nhiều AWS accounts

**AWS Organization là gì?**
- 1 master account quản lý nhiều child accounts
- Ví dụ:
  - Master account: Quản lý billing, policies
  - Dev account: Dùng cho development
  - Prod account: Dùng cho production

**Resources tạo ra**:
- AWS Organization
- Dev account
- Organizational Units (Development, Production)
- Service Control Policies (SCPs) - chính sách bảo mật

**Files**:
```
ops/1.organization/
├── main.tf       # Tạo organization, accounts, OUs
├── locals.tf     # Biến local
├── variables.tf  # Email cho dev/prod accounts
├── provider.tf   # AWS provider
└── outputs.tf    # Organization ID, account IDs
```

**Lưu ý**: Module này optional nếu bạn chỉ dùng 1 AWS account

---

### dev/0.iam_assume_role_terraform - IAM Roles

**Mục đích**: Tạo IAM roles với quyền hạn cụ thể

**IAM Role là gì?**
- "Vai trò" với quyền hạn nhất định
- AWS services assume role này để thực hiện actions
- Ví dụ: IoT Core assume role để write vào DynamoDB

**IAM Roles được tạo**:

1. **iot_core_service_role**:
   - IoT Core dùng role này
   - Quyền: Write vào DynamoDB, Timestream, SNS, CloudWatch Logs

2. **greengrass_core_role**:
   - Greengrass devices dùng role này
   - Quyền: Publish/Subscribe MQTT, Update Thing Shadow, Read S3

3. **iot_lambda_role**:
   - Lambda functions dùng role này
   - Quyền: Read/Write DynamoDB, Query Timestream, Write CloudWatch Logs

4. **api_gateway_role**:
   - API Gateway dùng role này
   - Quyền: Write CloudWatch Logs

**Files**:
```
dev/0.iam_assume_role_terraform/
├── main.tf       # Role existing (nếu có)
├── iot_roles.tf  # ⭐ IoT-specific roles (file mới)
└── provider.tf   # AWS provider
```

**File iot_roles.tf** chứa:
```hcl
# Tạo role
resource "aws_iam_role" "iot_core_service_role" {
  name = "aismc-dev-iot-core-service-role"

  # IoT Core có thể assume role này
  assume_role_policy = jsonencode({
    Statement = [{
      Action = "sts:AssumeRole"
      Principal = { Service = "iot.amazonaws.com" }
    }]
  })
}

# Gắn policy vào role (quyền write DynamoDB)
resource "aws_iam_role_policy" "iot_dynamodb_policy" {
  role = aws_iam_role.iot_core_service_role.id

  policy = jsonencode({
    Statement = [{
      Action = ["dynamodb:PutItem", "dynamodb:UpdateItem"]
      Resource = "arn:aws:dynamodb:...:table/aismc-dev-*"
    }]
  })
}
```

---

### dev/2.iot_core - IoT Core Infrastructure

**Mục đích**: Tạo AWS IoT Core resources

**AWS IoT Core là gì?**
- Service để quản lý IoT devices
- MQTT broker (nhận/gửi messages từ devices)
- Thing Groups: Tổ chức devices theo hierarchy
- Policies: Quyền hạn cho devices

**Resources tạo ra**:

1. **Thing Groups** (5 groups):
   ```
   Vietnam (root)
   ├── Northern-Region
   │   └── Hanoi-Site-001 (pilot site, 15K cameras)
   ├── Central-Region
   └── Southern-Region
   ```

2. **IoT Policies** (2 policies):
   - `greengrass-core-policy`: Full quyền cho Greengrass devices
   - `readonly-policy`: Read-only quyền (cho monitoring)

3. **Certificate Infrastructure**:
   - S3 bucket: Lưu certificate metadata
   - DynamoDB table: Track certificates (certificate_id, thing_name, status)

**Files**:
```
dev/2.iot_core/
├── main.tf            # Thing Groups hierarchy (dùng module)
├── iot_policies.tf    # IoT Policies
├── certificates.tf    # Certificate infrastructure (S3 + DynamoDB)
├── data.tf            # Data sources (IoT endpoints)
├── locals.tf          # Local variables
├── provider.tf        # AWS provider
├── outputs.tf         # Thing Group ARNs, Policy names, Endpoints
└── README.md          # Documentation
```

**Ví dụ tạo Thing Group bằng module**:
```hcl
module "vietnam_thing_group" {
  source = "../../_module/aws/iot/thing_group"  # Dùng module

  thing_group_name = "Vietnam"
  description      = "Root Thing Group for all Vietnam sites"

  attributes = {
    country     = "Vietnam"
    total_sites = "20"
  }

  tags = local.tags
}

module "hanoi_site_001_thing_group" {
  source = "../../_module/aws/iot/thing_group"

  thing_group_name  = "Hanoi-Site-001"
  parent_group_name = module.vietnam_thing_group.thing_group_name  # ⭐ Tham chiếu output
  description       = "Hanoi Pilot Site - 15,000 cameras"

  attributes = {
    site_id      = "site-001"
    camera_count = "15000"
  }
}
```

---

### dev/3.data_layer - Data Storage

**Mục đích**: Tạo databases để lưu trữ data

**Resources tạo ra**:

1. **DynamoDB DeviceRegistry**:
   - Lưu camera catalog (danh sách cameras)
   - Hash Key: `entity_id` (ID camera)
   - GSIs: `site_id-index`, `device_type-index`
   - Purpose: Static catalog (update 1x/day)

2. **DynamoDB CameraIncidents**:
   - Lưu incidents (camera offline events)
   - Hash Key: `incident_id`
   - Range Key: `timestamp`
   - GSIs: 4 indexes (site_id, entity_id, incident_type, status)
   - TTL: Enabled (tự động xóa old incidents)

3. **Timestream Database**:
   - Database: `iot-metrics`
   - Tables:
     - `camera-metrics`: Metrics từng camera (24h memory, 1 year magnetic)
     - `site-metrics`: Metrics theo site (24h memory, 1 year magnetic)
     - `system-metrics`: System health (7d memory, 2 years magnetic)

**Files**:
```
dev/3.data_layer/
├── dynamodb.tf    # DynamoDB tables (dùng module)
├── timestream.tf  # Timestream database + tables
├── locals.tf      # Local variables
├── provider.tf    # AWS provider
├── outputs.tf     # Table names, ARNs
└── README.md      # Documentation
```

**Ví dụ tạo DynamoDB table bằng module**:
```hcl
module "device_registry_table" {
  source = "../../_module/aws/data/dynamodb"

  table_name   = "aismc-dev-device-registry"
  billing_mode = "PAY_PER_REQUEST"  # On-demand pricing
  hash_key     = "entity_id"

  attributes = [
    { name = "entity_id",   type = "S" },  # S = String
    { name = "site_id",     type = "S" },
    { name = "device_type", type = "S" }
  ]

  global_secondary_indexes = [
    {
      name            = "site_id-index"
      hash_key        = "site_id"
      range_key       = ""
      projection_type = "ALL"
    }
  ]

  point_in_time_recovery = true  # Enable backups
}
```

---

### dev/4.iot_rules - IoT Rules Engine

**Mục đích**: Route MQTT messages từ IoT Core đến các services khác

**IoT Rules Engine là gì?**
- Lắng nghe messages trên MQTT topics
- Filter messages (SQL queries)
- Route messages đến DynamoDB, SNS, Timestream, Lambda, ...

**Resources tạo ra**:

1. **IoT Topic Rules** (4 rules):

   **a. incidents_to_dynamodb**:
   - Topic: `cameras/+/incidents`
   - SQL: `SELECT * FROM 'cameras/+/incidents'`
   - Action: Write to DynamoDB CameraIncidents table

   **b. registry_to_dynamodb**:
   - Topic: `cameras/+/registry`
   - SQL: `SELECT * FROM 'cameras/+/registry'`
   - Action: Write to DynamoDB DeviceRegistry table

   **c. critical_alerts_to_sns**:
   - Topic: `cameras/+/incidents`
   - SQL: `SELECT * WHERE incident_type = 'camera_offline' AND priority = 'critical'`
   - Action: Publish to SNS critical alerts topic

   **d. metrics_to_timestream**:
   - Topic: `cameras/+/metrics`
   - SQL: `SELECT * FROM 'cameras/+/metrics'`
   - Action: Write to Timestream camera-metrics table

2. **SNS Topics** (3 topics):
   - `critical-alerts`: Urgent incidents
   - `warning-alerts`: Warning events
   - `operational-notifications`: General notifications

3. **CloudWatch Log Group**:
   - Lưu errors từ IoT Rules

**Files**:
```
dev/4.iot_rules/
├── main.tf       # IoT Rules (4 rules)
├── sns.tf        # SNS topics + email subscriptions
├── variables.tf  # Alert email variable
├── locals.tf     # Local variables
├── provider.tf   # AWS provider
├── outputs.tf    # Rule ARNs, SNS topic ARNs
└── README.md     # Documentation
```

**Ví dụ IoT Rule**:
```hcl
resource "aws_iot_topic_rule" "incidents_to_dynamodb" {
  name        = "aismc_dev_incidents_to_dynamodb"
  description = "Route camera incidents to DynamoDB"
  enabled     = true
  sql         = "SELECT * FROM 'cameras/+/incidents'"  # MQTT topic filter
  sql_version = "2016-03-23"

  # Action: Write to DynamoDB
  dynamodb_v2 {
    role_arn = data.terraform_remote_state.iam.outputs.iot_core_service_role_arn

    put_item {
      table_name = data.terraform_remote_state.data_layer.outputs.camera_incidents_table_name
    }
  }

  # Error handling: Log to CloudWatch
  error_action {
    cloudwatch_logs {
      log_group_name = aws_cloudwatch_log_group.iot_rules_errors.name
      role_arn       = data.terraform_remote_state.iam.outputs.iot_core_service_role_arn
    }
  }
}
```

**Giải thích**:
- Message publish đến topic `cameras/site-001/incidents`
- IoT Rule match pattern `cameras/+/incidents` (+ = wildcard)
- SQL query select all fields
- Action: Write vào DynamoDB table `aismc-dev-camera-incidents`
- Nếu lỗi: Write error log vào CloudWatch

---

### dev/5.api_gateway - API Gateway + Lambda

**Mục đích**: Tạo REST API để query data từ DynamoDB

**API Endpoints**:
- `GET /cameras`: List cameras (từ DynamoDB DeviceRegistry)
- `GET /incidents`: List incidents (từ DynamoDB CameraIncidents)
- `GET /metrics`: Query metrics (future - từ Timestream)

**Resources tạo ra**:

1. **API Gateway**:
   - REST API
   - Resources: /cameras, /incidents, /metrics
   - Methods: GET, OPTIONS (CORS)
   - Stage: dev

2. **Lambda Functions** (2 functions):

   **a. get-cameras**:
   - Runtime: Python 3.11
   - Purpose: Query DynamoDB DeviceRegistry
   - Filters: site_id
   - Pagination: Supported

   **b. get-incidents**:
   - Runtime: Python 3.11
   - Purpose: Query DynamoDB CameraIncidents
   - Filters: site_id, entity_id, status, incident_type
   - Pagination: Supported
   - Sort: Timestamp descending (newest first)

3. **CloudWatch Log Groups**:
   - API Gateway logs
   - Lambda logs (per function)

**Files**:
```
dev/5.api_gateway/
├── main.tf                       # API Gateway resources
├── lambda.tf                     # Lambda functions
├── locals.tf                     # Local variables
├── provider.tf                   # AWS provider
├── outputs.tf                    # API endpoint URL
├── README.md                     # Documentation
└── lambda/
    ├── get_cameras/
    │   ├── index.py              # Python code
    │   └── requirements.txt      # Dependencies (empty - use boto3 from runtime)
    └── get_incidents/
        ├── index.py              # Python code
        └── requirements.txt
```

**Ví dụ Lambda function code** (`lambda/get_cameras/index.py`):
```python
import json
import os
import boto3

dynamodb = boto3.resource('dynamodb', region_name=os.environ['REGION'])
table = dynamodb.Table(os.environ['DEVICE_REGISTRY_TABLE'])

def handler(event, context):
    # Parse query parameters
    params = event.get('queryStringParameters', {}) or {}
    site_id = params.get('site_id')
    limit = int(params.get('limit', 100))

    # Query DynamoDB
    if site_id:
        response = table.query(
            IndexName='site_id-index',
            KeyConditionExpression='site_id = :site_id',
            ExpressionAttributeValues={':site_id': site_id},
            Limit=limit
        )
    else:
        response = table.scan(Limit=limit)

    # Return response
    return {
        'statusCode': 200,
        'headers': {'Content-Type': 'application/json'},
        'body': json.dumps({
            'cameras': response['Items'],
            'count': response['Count']
        })
    }
```

**Ví dụ Terraform tạo Lambda**:
```hcl
# Package Lambda code
data "archive_file" "get_cameras" {
  type        = "zip"
  source_dir  = "${path.module}/lambda/get_cameras"
  output_path = "${path.module}/lambda/get_cameras.zip"
}

# Create Lambda function
resource "aws_lambda_function" "get_cameras" {
  filename         = data.archive_file.get_cameras.output_path
  function_name    = "aismc-dev-get-cameras"
  role             = data.terraform_remote_state.iam.outputs.iot_lambda_role_arn
  handler          = "index.handler"
  runtime          = "python3.11"
  timeout          = 30
  memory_size      = 256

  environment {
    variables = {
      DEVICE_REGISTRY_TABLE = data.terraform_remote_state.data_layer.outputs.device_registry_table_name
      REGION                = "ap-southeast-1"
    }
  }
}

# Lambda permission for API Gateway
resource "aws_lambda_permission" "apigw_get_cameras" {
  statement_id  = "AllowAPIGatewayInvoke"
  action        = "lambda:InvokeFunction"
  function_name = aws_lambda_function.get_cameras.function_name
  principal     = "apigateway.amazonaws.com"
  source_arn    = "${aws_api_gateway_rest_api.aiops_api.execution_arn}/*/*"
}
```

---

## Terraform Workflow

```
1. Write Code (.tf files)
         ↓
2. terraform init     → Download providers, initialize backend
         ↓
3. terraform plan     → Preview changes (what will be created/deleted/updated)
         ↓
4. terraform apply    → Execute changes (create resources on AWS)
         ↓
5. Resources Created! → Check outputs: terraform output
```

### Chi Tiết Các Bước

**1. terraform init**:
```bash
cd dev/2.iot_core
terraform init
```

Làm gì?
- Download AWS provider plugin
- Initialize S3 backend (if configured)
- Download modules (if using)

Output:
```
Initializing the backend...
Initializing provider plugins...
- Finding hashicorp/aws versions matching "~> 5.0"...
- Installing hashicorp/aws v5.31.0...

Terraform has been successfully initialized!
```

**2. terraform plan**:
```bash
terraform plan -out=tfplan
```

Làm gì?
- So sánh code với state hiện tại
- Tính toán changes cần thực hiện
- Show preview (thêm/xóa/sửa cái gì)
- Lưu plan vào file `tfplan`

Output:
```
Terraform will perform the following actions:

  # aws_iot_thing_group.vietnam will be created
  + resource "aws_iot_thing_group" "vietnam" {
      + arn  = (known after apply)
      + name = "Vietnam"
      ...
    }

Plan: 5 to add, 0 to change, 0 to destroy.
```

Ký hiệu:
- `+` : Tạo mới
- `-` : Xóa
- `~` : Sửa (update in-place)
- `-/+`: Xóa rồi tạo lại (replace)

**3. terraform apply**:
```bash
terraform apply tfplan
```

Làm gì?
- Thực thi plan đã tạo
- Gọi AWS APIs để tạo resources
- Update state file
- Show outputs

Output:
```
aws_iot_thing_group.vietnam: Creating...
aws_iot_thing_group.vietnam: Creation complete after 2s [id=Vietnam]

Apply complete! Resources: 5 added, 0 changed, 0 destroyed.

Outputs:
vietnam_thing_group_arn = "arn:aws:iot:ap-southeast-1:123456789:thinggroup/Vietnam"
```

**4. terraform output**:
```bash
terraform output
terraform output vietnam_thing_group_arn
```

Xem outputs sau khi deploy.

**5. terraform destroy** (Khi cần xóa):
```bash
terraform destroy  # XÓA TẤT CẢ resources!!!
```

⚠️ **NGUY HIỂM**: Lệnh này XÓA tất cả resources. Chỉ dùng khi:
- Testing/development
- Muốn cleanup hoàn toàn

---

## Câu Lệnh Terraform Cơ Bản

### Khởi Tạo

```bash
terraform init              # Initialize directory
terraform init -upgrade     # Upgrade providers to latest version
terraform init -reconfigure # Reconfigure backend
```

### Planning & Applying

```bash
terraform plan                    # Preview changes
terraform plan -out=tfplan        # Save plan to file
terraform apply                   # Apply changes (interactive)
terraform apply tfplan            # Apply saved plan (no prompt)
terraform apply -auto-approve     # Apply without confirmation (DANGEROUS)
```

### Outputs

```bash
terraform output                  # Show all outputs
terraform output bucket_name      # Show specific output
terraform output -raw bucket_name # Show without quotes
terraform output -json            # JSON format
```

### State Management

```bash
terraform state list                              # List all resources in state
terraform state show aws_s3_bucket.my_bucket      # Show specific resource details
terraform state pull                              # Download remote state
terraform state rm aws_s3_bucket.my_bucket        # Remove resource from state (doesn't delete)
```

### Formatting & Validation

```bash
terraform fmt              # Format all .tf files in current dir
terraform fmt -recursive   # Format all .tf files recursively
terraform validate         # Validate syntax
```

### Workspace (Multiple Environments)

```bash
terraform workspace list           # List workspaces
terraform workspace new dev        # Create new workspace
terraform workspace select dev     # Switch workspace
```

### Destroy

```bash
terraform destroy                          # Destroy all resources
terraform destroy -target=aws_s3_bucket.my_bucket  # Destroy specific resource
```

### Import Existing Resources

```bash
terraform import aws_s3_bucket.my_bucket my-bucket-name
```

Import resource đã tồn tại vào Terraform state.

---

## Debugging

### Show Detailed Logs

```bash
export TF_LOG=DEBUG
terraform plan
```

Log levels: TRACE, DEBUG, INFO, WARN, ERROR

### Common Errors

**Error: No S3 backend configured**
```
Error: Backend initialization required
```
→ Run `terraform init` first

**Error: Resource already exists**
```
Error: creating S3 bucket: BucketAlreadyExists
```
→ Bucket name phải unique globally, đổi tên khác

**Error: Insufficient permissions**
```
Error: AccessDenied: User is not authorized to perform: s3:CreateBucket
```
→ Check AWS credentials, IAM permissions

**Error: State lock**
```
Error: Error acquiring the state lock
```
→ Ai đó đang chạy terraform. Đợi họ xong hoặc force unlock:
```bash
terraform force-unlock <LOCK_ID>
```

---

## Best Practices

### 1. Always Use Backend (S3)

❌ **Bad** (local state):
```hcl
# No backend config → state lưu local (terraform.tfstate)
```

✅ **Good** (remote state):
```hcl
backend "s3" {
  bucket = "aismc-nonprod-terraform-state"
  key    = "dev/iot-core/terraform.tfstate"
  region = "ap-southeast-1"
}
```

### 2. Use Variables for Reusability

❌ **Bad** (hardcode):
```hcl
resource "aws_s3_bucket" "my_bucket" {
  bucket = "aismc-dev-bucket"  # Hardcoded
}
```

✅ **Good** (variables):
```hcl
locals {
  bucket_name = "${local.product_name}-${local.environment}-bucket"
}

resource "aws_s3_bucket" "my_bucket" {
  bucket = local.bucket_name  # → "aismc-dev-bucket"
}
```

### 3. Use Modules for Reusability

❌ **Bad** (lặp code):
```hcl
resource "aws_iot_thing_group" "group1" { ... }
resource "aws_iot_thing_group" "group2" { ... }
resource "aws_iot_thing_group" "group3" { ... }
```

✅ **Good** (module):
```hcl
module "group1" {
  source = "../../_module/aws/iot/thing_group"
  thing_group_name = "Vietnam"
}
```

### 4. Always Plan Before Apply

❌ **Bad**:
```bash
terraform apply -auto-approve  # Nguy hiểm!
```

✅ **Good**:
```bash
terraform plan -out=tfplan    # Review changes
terraform apply tfplan        # Execute reviewed plan
```

### 5. Use Tags

✅ **Good**:
```hcl
provider "aws" {
  default_tags {
    tags = {
      Environment = "dev"
      ManagedBy   = "Terraform"
      Project     = "AIOps-IoC"
    }
  }
}
```

→ All resources tự động có tags này

---

## Tóm Tắt

### Files Terraform

| File | Mục Đích |
|---|---|
| `main.tf` | Định nghĩa resources chính |
| `variables.tf` | Input parameters |
| `locals.tf` | Local variables (internal) |
| `outputs.tf` | Export values |
| `provider.tf` | Provider config (AWS, region, backend) |
| `data.tf` | Data sources (read existing resources) |

### Workflow

```
terraform init → terraform plan → terraform apply → terraform output
```

### Module Structure

```
_module/<provider>/<category>/<resource>/
├── main.tf
├── variables.tf
└── outputs.tf
```

### Remote State

```hcl
data "terraform_remote_state" "other_module" {
  backend = "s3"
  config = {
    bucket = "..."
    key    = "..."
  }
}

# Sử dụng output từ module khác
resource "..." "..." {
  value = data.terraform_remote_state.other_module.outputs.something
}
```

---

**Tiếp theo**: Đọc [DEPLOYMENT-STEP-BY-STEP.md](DEPLOYMENT-STEP-BY-STEP.md) để triển khai từng bước!
