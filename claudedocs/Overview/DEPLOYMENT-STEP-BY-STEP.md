# Hướng Dẫn Triển Khai Chi Tiết Từng Bước (Step-by-Step Deployment Guide)

**Dành cho người mới bắt đầu không có kinh nghiệm với Terraform và AWS**

## Mục Lục

1. [Cài Đặt Các Công Cụ Cần Thiết](#1-cài-đặt-các-công-cụ-cần-thiết)
2. [Cấu Hình AWS Credentials](#2-cấu-hình-aws-credentials)
3. [Kiểm Tra Môi Trường](#3-kiểm-tra-môi-trường)
4. [Triển Khai Hạ Tầng](#4-triển-khai-hạ-tầng)
5. [Xác Minh Triển Khai](#5-xác-minh-triển-khai)
6. [Kiểm Thử Hệ Thống](#6-kiểm-thử-hệ-thống)
7. [Xử Lý Lỗi Thường Gặp](#7-xử-lý-lỗi-thường-gặp)
8. [Rollback và Xóa Hạ Tầng](#8-rollback-và-xóa-hạ-tầng)

---

## 1. Cài Đặt Các Công Cụ Cần Thiết

### 1.1 Cài Đặt AWS CLI

AWS CLI là công cụ dòng lệnh để tương tác với dịch vụ AWS.

#### Trên macOS:
```bash
# Tải AWS CLI
curl "https://awscli.amazonaws.com/AWSCLIV2.pkg" -o "AWSCLIV2.pkg"

# Cài đặt
sudo installer -pkg AWSCLIV2.pkg -target /
```

#### Trên Linux:
```bash
# Tải và cài đặt
curl "https://awscli.amazonaws.com/awscli-exe-linux-x86_64.zip" -o "awscliv2.zip"
unzip awscliv2.zip
sudo ./aws/install
```

#### Trên Windows:
1. Tải installer từ: https://awscli.amazonaws.com/AWSCLIV2.msi
2. Chạy file .msi và làm theo hướng dẫn

#### Kiểm tra cài đặt:
```bash
aws --version
```

**Kết quả mong đợi:**
```
aws-cli/2.x.x Python/3.x.x Darwin/XX.X.X botocore/2.x.x
```

---

### 1.2 Cài Đặt Terraform

Terraform là công cụ Infrastructure as Code chúng ta sử dụng để triển khai hạ tầng AWS.

#### Trên macOS (với Homebrew):
```bash
# Cài đặt Homebrew nếu chưa có
/bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)"

# Cài đặt Terraform
brew tap hashicorp/tap
brew install hashicorp/tap/terraform
```

#### Trên Linux:
```bash
# Tải Terraform
wget https://releases.hashicorp.com/terraform/1.7.0/terraform_1.7.0_linux_amd64.zip

# Giải nén và cài đặt
unzip terraform_1.7.0_linux_amd64.zip
sudo mv terraform /usr/local/bin/

# Phân quyền thực thi
sudo chmod +x /usr/local/bin/terraform
```

#### Trên Windows:
1. Tải Terraform từ: https://www.terraform.io/downloads
2. Giải nén file .zip
3. Thêm đường dẫn vào PATH environment variable

#### Kiểm tra cài đặt:
```bash
terraform version
```

**Kết quả mong đợi:**
```
Terraform v1.7.0
on darwin_amd64
```

---

### 1.3 Cài Đặt jq

jq là công cụ xử lý JSON từ dòng lệnh, cần thiết cho các script validation.

#### Trên macOS:
```bash
brew install jq
```

#### Trên Linux:
```bash
sudo apt-get update
sudo apt-get install jq
```

#### Trên Windows:
```bash
# Sử dụng Chocolatey
choco install jq
```

#### Kiểm tra cài đặt:
```bash
jq --version
```

**Kết quả mong đợi:**
```
jq-1.6
```

---

## 2. Cấu Hình AWS Credentials

### 2.1 Lấy AWS Access Keys

1. **Đăng nhập AWS Console**: https://console.aws.amazon.com
2. **Vào IAM Service**: Tìm "IAM" trong thanh tìm kiếm
3. **Chọn Users**: Click vào username của bạn
4. **Security Credentials tab**: Click tab "Security credentials"
5. **Create Access Key**:
   - Click "Create access key"
   - Chọn "CLI" use case
   - Download file .csv hoặc copy Access Key ID và Secret Access Key

⚠️ **LƯU Ý QUAN TRỌNG**: Secret Access Key chỉ hiển thị một lần. Lưu lại ngay!

---

### 2.2 Cấu Hình AWS CLI

Chạy lệnh sau và nhập thông tin:

```bash
aws configure
```

**Các câu hỏi sẽ xuất hiện:**

```
AWS Access Key ID [None]: <NHẬP ACCESS KEY ID>
AWS Secret Access Key [None]: <NHẬP SECRET ACCESS KEY>
Default region name [None]: ap-southeast-1
Default output format [None]: json
```

**Giải thích:**
- **Access Key ID**: Key ID bạn vừa tạo
- **Secret Access Key**: Secret key tương ứng
- **Region**: ap-southeast-1 (Singapore) - gần Vietnam nhất
- **Output format**: json - định dạng output dễ đọc

---

### 2.3 Kiểm Tra Kết Nối AWS

```bash
aws sts get-caller-identity
```

**Kết quả mong đợi:**
```json
{
    "UserId": "AIDAXXXXXXXXXXXXXXXXX",
    "Account": "123456789012",
    "Arn": "arn:aws:iam::123456789012:user/your-username"
}
```

✅ **Nếu thấy thông tin tài khoản**: Cấu hình thành công!
❌ **Nếu báo lỗi**: Kiểm tra lại Access Key và Secret Key

---

## 3. Kiểm Tra Môi Trường

### 3.1 Di Chuyển Vào Thư Mục Dự Án

```bash
cd /Users/hoangdat/Documents/2025/5.\ VSF/AWS\ IOT/AWS-IOT-LAB/cluster-nonprod-iac-main
```

**Giải thích**: Đây là thư mục chứa toàn bộ code Terraform của dự án

---

### 3.2 Xem Cấu Trúc Thư Mục

```bash
ls -la
```

**Kết quả mong đợi:**
```
drwxr-xr-x  ops/
drwxr-xr-x  dev/
drwxr-xr-x  _module/
drwxr-xr-x  scripts/
drwxr-xr-x  claudedocs/
-rw-r--r--  README.md
```

---

### 3.3 Kiểm Tra Scripts Có Thực Thi Được Không

```bash
# Phân quyền thực thi cho tất cả scripts
chmod +x scripts/*.sh

# Kiểm tra
ls -l scripts/
```

**Kết quả mong đợi**: Tất cả file .sh có chữ **x** trong quyền:
```
-rwxr-xr-x  deploy-week1-2.sh
-rwxr-xr-x  validate-infrastructure.sh
-rwxr-xr-x  create-iot-certificate.sh
-rwxr-xr-x  test-iot-message.sh
```

---

## 4. Triển Khai Hạ Tầng

Có 2 cách triển khai: **Tự động (Recommended)** hoặc **Thủ công từng bước**

---

### Lựa Chọn 1: Triển Khai Tự Động (Recommended) ⭐

#### Bước 4.1: Chạy Script Triển Khai

```bash
./scripts/deploy-week1-2.sh
```

**Quá trình này sẽ:**
1. Tạo S3 bucket để lưu trữ Terraform state (1-2 phút)
2. Triển khai IAM roles cho các dịch vụ (2-3 phút)
3. Tạo Thing Groups và IoT Policies (2-3 phút)
4. Tạo DynamoDB tables và Timestream database (3-4 phút)
5. Thiết lập IoT Rules và SNS topics (2-3 phút)
6. Deploy API Gateway và Lambda functions (3-4 phút)

**Tổng thời gian**: Khoảng 15-20 phút

#### Xem Output Của Script:

Script sẽ in ra nhiều thông tin. Bạn sẽ thấy:

```
[INFO] ========================================
[INFO] Week 1-2 Infrastructure Deployment
[INFO] ========================================

[INFO] Step 0: Initializing S3 backend...
[INFO] Creating Terraform state storage...

Terraform used the selected providers to generate the following execution
plan. Resource actions are indicated with the following symbols:
  + create

Terraform will perform the following actions:
  # aws_s3_bucket.terraform_state will be created
  + resource "aws_s3_bucket" "terraform_state" {
      + bucket = "aismc-dev-terraform-state-123456789012"
      ...
    }

Plan: 3 to add, 0 to change, 0 to destroy.

aws_s3_bucket.terraform_state: Creating...
aws_s3_bucket.terraform_state: Creation complete after 2s

[SUCCESS] S3 backend created successfully!
```

**Các trạng thái bạn sẽ thấy:**
- `[INFO]`: Thông tin bước đang thực hiện
- `[SUCCESS]`: Bước hoàn thành thành công ✅
- `[ERROR]`: Có lỗi xảy ra ❌
- `[WARNING]`: Cảnh báo cần chú ý ⚠️

#### Nếu Script Chạy Thành Công:

```
[SUCCESS] ========================================
[SUCCESS] Week 1-2 Deployment Complete!
[SUCCESS] ========================================

[INFO] Infrastructure Components Deployed:
  - S3 Backend for Terraform state
  - IAM roles for IoT, Lambda, API Gateway
  - IoT Core: Thing Groups and Policies
  - Data Layer: 2 DynamoDB tables, 3 Timestream tables
  - Integration: 4 IoT Rules, 3 SNS topics
  - API Layer: REST API with 2 Lambda functions

[INFO] Next Steps:
  1. Run validation: ./scripts/validate-infrastructure.sh
  2. Create IoT certificate: ./scripts/create-iot-certificate.sh site-001
  3. Test API endpoints: see dev/5.api_gateway/README.md
```

✅ **Nếu thấy SUCCESS**: Chuyển sang [Bước 5: Xác Minh Triển Khai](#5-xác-minh-triển-khai)
❌ **Nếu thấy ERROR**: Xem [Phần 7: Xử Lý Lỗi](#7-xử-lý-lỗi-thường-gặp)

---

### Lựa Chọn 2: Triển Khai Thủ Công Từng Bước

Nếu bạn muốn hiểu rõ từng bước hoặc script tự động gặp lỗi, làm theo hướng dẫn này.

---

#### Bước 4.2.1: Tạo S3 Backend

**Mục đích**: Tạo S3 bucket để lưu trữ Terraform state, cho phép làm việc nhóm

```bash
cd ops/0.init_s3_backend
```

**Khởi tạo Terraform:**
```bash
terraform init
```

**Kết quả mong đợi:**
```
Initializing the backend...
Initializing provider plugins...
- Finding hashicorp/aws versions matching "~> 5.0"...
- Installing hashicorp/aws v5.31.0...

Terraform has been successfully initialized!
```

**Giải thích**: Terraform đang tải các plugin cần thiết để kết nối với AWS

**Xem trước những gì sẽ được tạo:**
```bash
terraform plan -out=tfplan
```

**Kết quả mong đợi:**
```
Terraform will perform the following actions:

  # aws_s3_bucket.terraform_state will be created
  + resource "aws_s3_bucket" "terraform_state" {
      + bucket = "aismc-dev-terraform-state-123456789012"
      ...
    }

Plan: 3 to add, 0 to change, 0 to destroy.
```

**Giải thích**: Terraform sẽ tạo 3 resources:
1. S3 bucket (lưu trữ state)
2. S3 bucket versioning (backup state)
3. DynamoDB table (khóa state để tránh xung đột)

**Triển khai:**
```bash
terraform apply tfplan
```

**Kết quả mong đợi:**
```
aws_s3_bucket.terraform_state: Creating...
aws_s3_bucket.terraform_state: Creation complete after 2s
aws_dynamodb_table.terraform_lock: Creating...
aws_dynamodb_table.terraform_lock: Creation complete after 5s

Apply complete! Resources: 3 added, 0 changed, 0 destroyed.

Outputs:

s3_bucket_name = "aismc-dev-terraform-state-123456789012"
```

✅ **Kiểm tra thành công**: Bạn sẽ thấy "Apply complete! Resources: 3 added"

**Quay lại thư mục gốc:**
```bash
cd ../..
```

---

#### Bước 4.2.2: Triển Khai IAM Roles

**Mục đích**: Tạo các IAM roles cho IoT Core, Lambda, API Gateway, Greengrass

```bash
cd dev/0.iam_assume_role_terraform
```

**Khởi tạo và cấu hình backend:**
```bash
terraform init
```

**Kết quả mong đợi:**
```
Initializing the backend...

Successfully configured the backend "s3"! Terraform will automatically
use this backend unless the backend configuration changes.
```

**Giải thích**: Terraform đang kết nối với S3 bucket vừa tạo để lưu state

**Xem trước:**
```bash
terraform plan -out=tfplan
```

**Kết quả mong đợi:**
```
Plan: 12 to add, 0 to change, 0 to destroy.
```

**Giải thích**: Sẽ tạo 12 resources (4 IAM roles + 8 policies)

**Triển khai:**
```bash
terraform apply tfplan
```

**Quá trình này mất khoảng 2-3 phút**

**Kết quả mong đợi:**
```
Apply complete! Resources: 12 added, 0 changed, 0 destroyed.

Outputs:

iot_core_service_role_arn = "arn:aws:iam::123456789012:role/aismc-dev-iot-core-service-role"
greengrass_core_role_arn = "arn:aws:iam::123456789012:role/aismc-dev-greengrass-core-role"
lambda_execution_role_arn = "arn:aws:iam::123456789012:role/aismc-dev-lambda-execution-role"
api_gateway_role_arn = "arn:aws:iam::123456789012:role/aismc-dev-api-gateway-role"
```

**Quay lại thư mục gốc:**
```bash
cd ../..
```

---

#### Bước 4.2.3: Triển Khai IoT Core

**Mục đích**: Tạo Thing Groups (Vietnam → Regions → Sites) và IoT Policies

```bash
cd dev/2.iot_core
```

**Khởi tạo:**
```bash
terraform init
```

**Xem trước:**
```bash
terraform plan -out=tfplan
```

**Kết quả mong đợi:**
```
Plan: 15 to add, 0 to change, 0 to destroy.
```

**Giải thích**: Sẽ tạo:
- 6 Thing Groups (Vietnam, 3 Regions, 1 Site Hanoi, 1 Site pilot)
- 2 IoT Policies (Greengrass Core, Read-only)
- 5 supporting resources (S3 bucket for certs, DynamoDB table, etc.)

**Triển khai:**
```bash
terraform apply tfplan
```

**Kết quả mong đợi:**
```
Apply complete! Resources: 15 added, 0 changed, 0 destroyed.

Outputs:

vietnam_thing_group_arn = "arn:aws:iot:ap-southeast-1:123456789012:thinggroup/Vietnam"
hanoi_site_001_thing_group_arn = "arn:aws:iot:ap-southeast-1:123456789012:thinggroup/Hanoi-Site-001"
greengrass_core_policy_name = "aismc-dev-greengrass-core-policy"
iot_data_endpoint = "abcdefg123456-ats.iot.ap-southeast-1.amazonaws.com"
```

**Lưu lại IoT endpoint** (cần cho bước sau):
```bash
terraform output -raw iot_data_endpoint
```

**Quay lại thư mục gốc:**
```bash
cd ../..
```

---

#### Bước 4.2.4: Triển Khai Data Layer

**Mục đích**: Tạo DynamoDB tables (DeviceRegistry, CameraIncidents) và Timestream database

```bash
cd dev/3.data_layer
```

**Khởi tạo:**
```bash
terraform init
```

**Xem trước:**
```bash
terraform plan -out=tfplan
```

**Kết quả mong đợi:**
```
Plan: 9 to add, 0 to change, 0 to destroy.
```

**Giải thích**: Sẽ tạo:
- 2 DynamoDB tables với GSIs, TTL, Point-in-time recovery
- 1 Timestream database
- 3 Timestream tables (camera-metrics, site-metrics, system-metrics)
- Supporting resources

**Triển khai:**
```bash
terraform apply tfplan
```

**Quá trình này mất khoảng 3-4 phút** (DynamoDB + Timestream tạo hơi lâu)

**Kết quả mong đợi:**
```
Apply complete! Resources: 9 added, 0 changed, 0 destroyed.

Outputs:

device_registry_table_name = "aismc-dev-device-registry"
camera_incidents_table_name = "aismc-dev-camera-incidents"
timestream_database_name = "aismc-dev-iot-metrics"
timestream_tables = {
  "camera_metrics" = "camera-metrics"
  "site_metrics" = "site-metrics"
  "system_metrics" = "system-metrics"
}
```

**Quay lại thư mục gốc:**
```bash
cd ../..
```

---

#### Bước 4.2.5: Triển Khai IoT Rules Engine

**Mục đích**: Tạo IoT Rules để route messages và SNS topics cho alerting

```bash
cd dev/4.iot_rules
```

**Khởi tạo:**
```bash
terraform init
```

**Xem trước:**
```bash
terraform plan -out=tfplan
```

**Kết quả mong đợi:**
```
Plan: 11 to add, 0 to change, 0 to destroy.
```

**Giải thích**: Sẽ tạo:
- 4 IoT Topic Rules (incidents → DynamoDB, registry → DynamoDB, metrics → Timestream, critical alerts → SNS)
- 3 SNS Topics (critical, warning, operational)
- 1 CloudWatch Log Group (for error handling)
- Supporting resources

**Triển khai:**
```bash
terraform apply tfplan
```

**Kết quả mong đợi:**
```
Apply complete! Resources: 11 added, 0 changed, 0 destroyed.

Outputs:

iot_rules = {
  "incidents_to_dynamodb" = "aismc_dev_incidents_to_dynamodb"
  "registry_to_dynamodb" = "aismc_dev_registry_to_dynamodb"
  "metrics_to_timestream" = "aismc_dev_metrics_to_timestream"
  "critical_alerts_to_sns" = "aismc_dev_critical_alerts_to_sns"
}
sns_topics = {
  "critical_alerts" = "arn:aws:sns:ap-southeast-1:123456789012:aismc-dev-critical-alerts"
  "warning_alerts" = "arn:aws:sns:ap-southeast-1:123456789012:aismc-dev-warning-alerts"
  "operational_notifications" = "arn:aws:sns:ap-southeast-1:123456789012:aismc-dev-operational-notifications"
}
```

**⚠️ Lưu ý**: Nếu bạn cung cấp email trong variables, kiểm tra inbox để confirm SNS subscription!

**Quay lại thư mục gốc:**
```bash
cd ../..
```

---

#### Bước 4.2.6: Triển Khai API Gateway và Lambda

**Mục đích**: Tạo REST API với Lambda functions để query DynamoDB

```bash
cd dev/5.api_gateway
```

**Khởi tạo:**
```bash
terraform init
```

**Xem trước:**
```bash
terraform plan -out=tfplan
```

**Kết quả mong đợi:**
```
Plan: 20 to add, 0 to change, 0 to destroy.
```

**Giải thích**: Sẽ tạo:
- 1 API Gateway REST API
- 2 Lambda functions (get-cameras, get-incidents)
- API resources (/cameras, /incidents)
- Methods (GET, OPTIONS for CORS)
- Lambda permissions
- API deployment and stage

**Triển khai:**
```bash
terraform apply tfplan
```

**Kết quả mong đợi:**
```
Apply complete! Resources: 20 added, 0 changed, 0 destroyed.

Outputs:

api_gateway_endpoint = "https://abcd1234.execute-api.ap-southeast-1.amazonaws.com/dev"
cameras_endpoint = "https://abcd1234.execute-api.ap-southeast-1.amazonaws.com/dev/cameras"
incidents_endpoint = "https://abcd1234.execute-api.ap-southeast-1.amazonaws.com/dev/incidents"
lambda_functions = {
  "get_cameras" = "arn:aws:lambda:ap-southeast-1:123456789012:function:aismc-dev-get-cameras"
  "get_incidents" = "arn:aws:lambda:ap-southeast-1:123456789012:function:aismc-dev-get-incidents"
}
```

**Lưu lại API endpoint** (cần cho testing):
```bash
API_ENDPOINT=$(terraform output -raw api_gateway_endpoint)
echo "API Endpoint: $API_ENDPOINT"
```

**Quay lại thư mục gốc:**
```bash
cd ../..
```

---

## 5. Xác Minh Triển Khai

### 5.1 Chạy Script Validation

```bash
./scripts/validate-infrastructure.sh
```

**Kết quả mong đợi:**

```
========================================
Infrastructure Validation
========================================

Checking S3 Backend...
✅ S3 bucket exists: aismc-dev-terraform-state-123456789012
✅ DynamoDB lock table exists: aismc-dev-terraform-lock

Checking IAM Roles...
✅ IoT Core service role exists
✅ Greengrass core role exists
✅ Lambda execution role exists
✅ API Gateway role exists

Checking IoT Core...
✅ Thing Group 'Vietnam' exists
✅ Thing Group 'Hanoi-Site-001' exists
✅ IoT Policy 'aismc-dev-greengrass-core-policy' exists

Checking DynamoDB Tables...
✅ Table 'aismc-dev-device-registry' is ACTIVE
✅ Table 'aismc-dev-camera-incidents' is ACTIVE

Checking Timestream...
✅ Database 'aismc-dev-iot-metrics' exists
✅ Table 'camera-metrics' is ACTIVE
✅ Table 'site-metrics' is ACTIVE
✅ Table 'system-metrics' is ACTIVE

Checking IoT Rules...
✅ Rule 'aismc_dev_incidents_to_dynamodb' is ENABLED
✅ Rule 'aismc_dev_registry_to_dynamodb' is ENABLED
✅ Rule 'aismc_dev_metrics_to_timestream' is ENABLED
✅ Rule 'aismc_dev_critical_alerts_to_sns' is ENABLED

Checking API Gateway...
✅ API 'aismc-dev-aiops-api' exists
✅ Lambda 'aismc-dev-get-cameras' is Active
✅ Lambda 'aismc-dev-get-incidents' is Active

========================================
Validation Complete: ALL CHECKS PASSED ✅
========================================
```

✅ **Nếu tất cả checks PASSED**: Triển khai hoàn toàn thành công!
❌ **Nếu có checks FAILED**: Xem [Phần 7: Xử Lý Lỗi](#7-xử-lý-lỗi-thường-gặp)

---

### 5.2 Kiểm Tra Resources Trên AWS Console

#### Kiểm tra IoT Core:
1. Đăng nhập AWS Console: https://console.aws.amazon.com
2. Chuyển region về **ap-southeast-1** (Singapore) ở góc trên bên phải
3. Tìm "IoT Core" trong thanh tìm kiếm
4. Vào **Manage** → **Thing groups**
5. Bạn sẽ thấy: Vietnam, Northern-Region, Central-Region, Southern-Region, Hanoi-Site-001

#### Kiểm tra DynamoDB:
1. Tìm "DynamoDB" trong thanh tìm kiếm
2. Click **Tables** ở sidebar
3. Bạn sẽ thấy:
   - `aismc-dev-device-registry`
   - `aismc-dev-camera-incidents`

#### Kiểm tra Lambda:
1. Tìm "Lambda" trong thanh tìm kiếm
2. Click **Functions**
3. Bạn sẽ thấy:
   - `aismc-dev-get-cameras`
   - `aismc-dev-get-incidents`

#### Kiểm tra API Gateway:
1. Tìm "API Gateway" trong thanh tìm kiếm
2. Bạn sẽ thấy: `aismc-dev-aiops-api`
3. Click vào API → **Stages** → **dev**
4. Copy **Invoke URL** (đây chính là API endpoint)

---

## 6. Kiểm Thử Hệ Thống

### 6.1 Tạo IoT Certificate (Optional - cho Pilot Site)

```bash
./scripts/create-iot-certificate.sh site-001
```

**Kết quả mong đợi:**
```
Creating IoT certificate for site: site-001

Certificate created successfully!
Certificate ID: abc123def456...
Certificate ARN: arn:aws:iot:ap-southeast-1:123456789012:cert/abc123def456...

Files saved:
  - ./certificates/site-001-certificate.pem.crt
  - ./certificates/site-001-private.pem.key
  - ./certificates/site-001-public.pem.key

Certificate attached to policy: aismc-dev-greengrass-core-policy

IMPORTANT: Keep private key secure! This is the only time you can download it.
```

---

### 6.2 Kiểm Thử API Endpoints

#### Test 1: Query Cameras (trước khi có data)

```bash
cd dev/5.api_gateway
API_ENDPOINT=$(terraform output -raw api_gateway_endpoint)
curl "${API_ENDPOINT}/cameras?limit=10"
```

**Kết quả mong đợi** (vì chưa có data):
```json
{
  "cameras": [],
  "count": 0
}
```

✅ **Giải thích**: API hoạt động đúng, nhưng chưa có camera nào trong database

---

#### Test 2: Query Incidents

```bash
curl "${API_ENDPOINT}/incidents?limit=10"
```

**Kết quả mong đợi**:
```json
{
  "incidents": [],
  "count": 0
}
```

---

#### Test 3: Thêm Test Data Vào DynamoDB

**Tạo file test data:**
```bash
cat > test-camera.json <<EOF
{
  "entity_id": {"S": "urn:ngsi-ld:Camera:camera-001"},
  "site_id": {"S": "site-001"},
  "device_type": {"S": "IP_Camera"},
  "type": {"S": "Camera"},
  "@context": {"S": "https://uri.etsi.org/ngsi-ld/v1/ngsi-ld-core-context.jsonld"}
}
EOF
```

**Thêm data vào DynamoDB:**
```bash
cd ../../dev/3.data_layer
TABLE_NAME=$(terraform output -raw device_registry_table_name)
aws dynamodb put-item \
  --table-name $TABLE_NAME \
  --item file://../../test-camera.json \
  --region ap-southeast-1
```

**Kiểm tra lại API:**
```bash
cd ../5.api_gateway
API_ENDPOINT=$(terraform output -raw api_gateway_endpoint)
curl "${API_ENDPOINT}/cameras?limit=10"
```

**Kết quả mong đợi** (bây giờ có data):
```json
{
  "cameras": [
    {
      "entity_id": "urn:ngsi-ld:Camera:camera-001",
      "site_id": "site-001",
      "device_type": "IP_Camera",
      "type": "Camera",
      "@context": "https://uri.etsi.org/ngsi-ld/v1/ngsi-ld-core-context.jsonld"
    }
  ],
  "count": 1
}
```

✅ **Nếu thấy data trả về**: API hoạt động hoàn hảo!

---

#### Test 4: Kiểm Thử IoT Message Publishing (Optional)

**Tạo test incident message:**
```bash
cat > test-incident.json <<EOF
{
  "incident_id": "inc-test-001",
  "timestamp": "$(date -u +%Y-%m-%dT%H:%M:%SZ)",
  "site_id": "site-001",
  "entity_id": "camera-001",
  "incident_type": "camera_offline",
  "status": "active",
  "priority": "critical",
  "description": "Camera offline test"
}
EOF
```

**Publish message tới IoT Core:**
```bash
./scripts/test-iot-message.sh cameras/site-001/incidents
```

**Kiểm tra message có vào DynamoDB không:**
```bash
cd dev/3.data_layer
TABLE_NAME=$(terraform output -raw camera_incidents_table_name)
aws dynamodb scan --table-name $TABLE_NAME --limit 10 --region ap-southeast-1
```

**Kết quả mong đợi**:
```json
{
    "Items": [
        {
            "incident_id": {"S": "inc-test-001"},
            "timestamp": {"S": "2025-12-30T10:00:00Z"},
            "site_id": {"S": "site-001"},
            "entity_id": {"S": "camera-001"},
            "incident_type": {"S": "camera_offline"},
            "status": {"S": "active"},
            "priority": {"S": "critical"}
        }
    ],
    "Count": 1
}
```

✅ **Nếu thấy incident trong DynamoDB**: IoT Rules đang route messages đúng!

---

## 7. Xử Lý Lỗi Thường Gặp

### Lỗi 1: AWS Credentials Không Hợp Lệ

**Biểu hiện:**
```
Error: error configuring Terraform AWS Provider: no valid credential sources
```

**Nguyên nhân**: AWS credentials chưa được cấu hình hoặc không hợp lệ

**Cách khắc phục:**
```bash
# Kiểm tra credentials
aws sts get-caller-identity

# Nếu lỗi, cấu hình lại
aws configure
```

---

### Lỗi 2: Region Không Đúng

**Biểu hiện:**
```
Error: Error creating Thing Group: InvalidRequestException: Region not supported
```

**Nguyên nhân**: Region trong AWS config không phải ap-southeast-1

**Cách khắc phục:**
```bash
# Xem region hiện tại
aws configure get region

# Đổi sang ap-southeast-1
aws configure set region ap-southeast-1
```

---

### Lỗi 3: S3 Bucket Name Đã Tồn Tại

**Biểu hiện:**
```
Error: error creating S3 bucket: BucketAlreadyExists
```

**Nguyên nhân**: S3 bucket name phải unique globally, có người đã dùng tên này

**Cách khắc phục:**

1. Mở file `ops/0.init_s3_backend/main.tf`
2. Sửa dòng bucket name:
```hcl
resource "aws_s3_bucket" "terraform_state" {
  bucket = "${local.product_name}-${local.environment}-terraform-state-${local.account_id}-v2"  # Thêm -v2
  ...
}
```
3. Chạy lại:
```bash
terraform plan -out=tfplan
terraform apply tfplan
```

---

### Lỗi 4: IAM Permissions Không Đủ

**Biểu hiện:**
```
Error: error creating IoT Thing Group: AccessDeniedException
```

**Nguyên nhân**: IAM user của bạn không có quyền tạo IoT resources

**Cách khắc phục:**

Liên hệ AWS Administrator để gán policies sau:
- `IAMFullAccess`
- `AWSIoTFullAccess`
- `AmazonDynamoDBFullAccess`
- `AWSLambda_FullAccess`
- `AmazonAPIGatewayAdministrator`
- `AmazonTimestreamFullAccess`

Hoặc attach policy: `AdministratorAccess` (cho non-production)

---

### Lỗi 5: Terraform State Lock

**Biểu hiện:**
```
Error: Error acquiring the state lock
Lock Info:
  ID:        abc123-def456-...
  Operation: OperationTypeApply
  Who:       user@hostname
  Created:   2025-12-30 10:00:00
```

**Nguyên nhân**: Có Terraform process khác đang chạy hoặc bị crash trước đó

**Cách khắc phục:**

**Option 1**: Đợi process kia hoàn thành (nếu đồng nghiệp đang chạy)

**Option 2**: Force unlock (nếu bạn chắc chắn không có process nào đang chạy)
```bash
# Copy Lock ID từ error message
terraform force-unlock abc123-def456-...
```

---

### Lỗi 6: Lambda Deployment Package Too Large

**Biểu hiện:**
```
Error: error creating Lambda Function: InvalidParameterValueException: Unzipped size must be smaller than 262144000 bytes
```

**Nguyên nhân**: Lambda code package quá lớn

**Cách khắc phục:**

Trong trường hợp này, code đã được tối ưu sẵn. Nếu vẫn lỗi:
```bash
# Kiểm tra kích thước
cd dev/5.api_gateway/lambda/get_cameras
du -sh *

# Xóa cache nếu có
rm -rf __pycache__
```

---

### Lỗi 7: API Gateway 403 Forbidden

**Biểu hiện:**
```bash
curl https://xxx.execute-api.ap-southeast-1.amazonaws.com/dev/cameras
{"message":"Forbidden"}
```

**Nguyên nhân**: Lambda permission chưa được gán cho API Gateway

**Cách khắc phục:**
```bash
cd dev/5.api_gateway
terraform destroy -target=aws_lambda_permission.api_gateway_get_cameras
terraform apply
```

---

### Lỗi 8: DynamoDB Table Already Exists

**Biểu hiện:**
```
Error: error creating DynamoDB Table: ResourceInUseException: Table already exists
```

**Nguyên nhân**: Đã chạy terraform apply trước đó

**Cách khắc phục:**

**Option 1**: Import existing table
```bash
terraform import module.device_registry_table.aws_dynamodb_table.this aismc-dev-device-registry
```

**Option 2**: Xóa và tạo lại (CHỈ cho development, SẼ MẤT DATA!)
```bash
aws dynamodb delete-table --table-name aismc-dev-device-registry --region ap-southeast-1
terraform apply
```

---

## 8. Rollback và Xóa Hạ Tầng

### 8.1 Xóa Từng Module (Theo Thứ Tự Ngược)

⚠️ **LƯU Ý**: Thao tác này sẽ XÓA HOÀN TOÀN hạ tầng và DATA!

**Bước 1: Xóa API Gateway**
```bash
cd dev/5.api_gateway
terraform destroy
# Type 'yes' to confirm
cd ../..
```

**Bước 2: Xóa IoT Rules**
```bash
cd dev/4.iot_rules
terraform destroy
cd ../..
```

**Bước 3: Xóa Data Layer**
```bash
cd dev/3.data_layer
terraform destroy
cd ../..
```

**Bước 4: Xóa IoT Core**
```bash
cd dev/2.iot_core
terraform destroy
cd ../..
```

**Bước 5: Xóa IAM Roles**
```bash
cd dev/0.iam_assume_role_terraform
terraform destroy
cd ../..
```

**Bước 6: Xóa S3 Backend** (cuối cùng)
```bash
cd ops/0.init_s3_backend

# Xóa tất cả objects trong bucket trước
BUCKET_NAME=$(terraform output -raw s3_bucket_name)
aws s3 rm s3://$BUCKET_NAME --recursive

# Xóa bucket và DynamoDB table
terraform destroy
cd ../..
```

---

### 8.2 Xóa Tất Cả Bằng Script (Nhanh Hơn)

```bash
./scripts/destroy-all.sh
```

**⚠️ Cảnh báo sẽ xuất hiện:**
```
WARNING: This will DELETE ALL infrastructure!
All data in DynamoDB and Timestream will be LOST!
Are you sure? (type 'yes' to confirm):
```

Type **yes** để xác nhận

**Quá trình xóa mất khoảng 10-15 phút**

---

### 8.3 Kiểm Tra Xóa Hoàn Tất

```bash
# Kiểm tra DynamoDB tables
aws dynamodb list-tables --region ap-southeast-1 | grep aismc-dev

# Kiểm tra IoT Thing Groups
aws iot list-thing-groups --region ap-southeast-1 | grep Vietnam

# Kiểm tra Lambda functions
aws lambda list-functions --region ap-southeast-1 | grep aismc-dev

# Kiểm tra API Gateway
aws apigateway get-rest-apis --region ap-southeast-1 | grep aismc-dev
```

**Kết quả mong đợi**: Không có output nào (tất cả đã bị xóa)

---

## 9. Các Lệnh Terraform Hữu Ích

### Xem State Hiện Tại
```bash
terraform state list
```

### Xem Chi Tiết Một Resource
```bash
terraform state show aws_dynamodb_table.device_registry
```

### Xem Output Values
```bash
terraform output
```

### Format Code Terraform
```bash
terraform fmt -recursive
```

### Validate Syntax
```bash
terraform validate
```

### Refresh State (đồng bộ với AWS)
```bash
terraform refresh
```

### Xem Dependency Graph
```bash
terraform graph | dot -Tpng > graph.png
```

---

## 10. Best Practices

### ✅ Nên Làm:

1. **Luôn chạy `terraform plan` trước `terraform apply`**
   - Xem trước những thay đổi sẽ xảy ra

2. **Commit Terraform state vào Git? KHÔNG!**
   - State chứa thông tin nhạy cảm
   - Đã lưu trong S3 backend rồi

3. **Sao lưu State thường xuyên**
   - S3 bucket đã bật versioning
   - Có thể restore state từ versions trước

4. **Sử dụng modules cho reusability**
   - Đã có trong `_module/aws/`
   - Tránh duplicate code

5. **Tag tất cả resources**
   - Đã config trong `locals.tf`
   - Giúp tracking cost và resource management

### ❌ Không Nên Làm:

1. **Không edit resources trực tiếp trên AWS Console**
   - Sẽ gây drift với Terraform state
   - Luôn dùng Terraform để thay đổi

2. **Không share AWS credentials trong code**
   - Dùng `aws configure` hoặc IAM roles
   - Không commit credentials vào Git

3. **Không skip plan step**
   - Luôn xem trước với `terraform plan`
   - Tránh thay đổi không mong muốn

4. **Không `terraform destroy` trên production**
   - Chỉ destroy trên dev/test environment
   - Production cần approval process

---

## 11. Tài Liệu Tham Khảo

### Terraform Documentation:
- **Terraform AWS Provider**: https://registry.terraform.io/providers/hashicorp/aws/latest/docs
- **Terraform Language**: https://developer.hashicorp.com/terraform/language

### AWS Documentation:
- **IoT Core**: https://docs.aws.amazon.com/iot/
- **DynamoDB**: https://docs.aws.amazon.com/dynamodb/
- **Lambda**: https://docs.aws.amazon.com/lambda/
- **API Gateway**: https://docs.aws.amazon.com/apigateway/

### Project Documentation:
- **[TERRAFORM-GUIDE.md](TERRAFORM-GUIDE.md)**: Hướng dẫn Terraform toàn diện
- **[WEEK-1-2-INFRASTRUCTURE-PLAN.md](WEEK-1-2-INFRASTRUCTURE-PLAN.md)**: Kế hoạch chi tiết
- **[EXECUTIVE-SUMMARY.md](EXECUTIVE-SUMMARY.md)**: Tổng quan dự án

---

## 12. Hỗ Trợ và Liên Hệ

### Gặp vấn đề không thể giải quyết?

1. **Kiểm tra CloudWatch Logs:**
```bash
# Lambda logs
aws logs tail /aws/lambda/aismc-dev-get-cameras --follow

# IoT Rules logs
aws logs tail /aws/iot/rules/aismc-dev/errors --follow
```

2. **Kiểm tra Terraform state:**
```bash
terraform state list
terraform state show <resource_name>
```

3. **Enable debug mode:**
```bash
export TF_LOG=DEBUG
terraform apply
```

4. **Tham khảo error messages trong:**
   - AWS CloudWatch Logs
   - Terraform output
   - Script output (`deploy-week1-2.sh`, `validate-infrastructure.sh`)

---

## 13. Checklist Hoàn Tất

Sau khi hoàn thành tất cả bước, đánh dấu checklist:

- [ ] Cài đặt AWS CLI, Terraform, jq
- [ ] Cấu hình AWS credentials
- [ ] Deploy S3 backend
- [ ] Deploy IAM roles
- [ ] Deploy IoT Core
- [ ] Deploy Data Layer
- [ ] Deploy IoT Rules
- [ ] Deploy API Gateway
- [ ] Chạy validation script - ALL CHECKS PASSED
- [ ] Test API endpoints thành công
- [ ] (Optional) Tạo IoT certificate
- [ ] (Optional) Test IoT message publishing
- [ ] Lưu trữ outputs quan trọng (API endpoint, table names, etc.)

---

## Chúc Mừng! 🎉

Bạn đã hoàn thành triển khai **AIOps IoC Platform - Week 1-2 Infrastructure**!

**Hạ tầng hiện có:**
- ✅ IoT Core với Thing Groups hierarchy
- ✅ DynamoDB tables cho device registry và incidents
- ✅ Timestream database cho time-series metrics
- ✅ IoT Rules Engine routing messages
- ✅ REST API với Lambda functions
- ✅ SNS topics cho alerting

**Bước tiếp theo:**
- Week 3: Develop Greengrass Components
- Week 4: Deploy Pilot Site (Hanoi Site 001)
- Integration với DMP và SmartHUB

Good luck! 🚀
