# GIAI ĐOẠN 1: FIX GREENGRASS CONNECTIVITY - DEPLOYMENT SUMMARY

**Ngày hoàn thành**: 2025-12-31
**Thời gian thực hiện**: ~1 giờ

---

## ✅ ĐÃ HOÀN THÀNH

### 1. Infrastructure as Code (Terraform)

#### **Module Mới**: `_module/aws/iot/greengrass_thing/`
- ✅ Tạo IoT Thing với Thing Type
- ✅ Tạo và kích hoạt X.509 certificates
- ✅ Attach certificate với Thing
- ✅ Attach policy với certificate
- ✅ Add Thing vào Thing Group
- ✅ Lưu credentials vào AWS SSM Parameter Store (encrypted)
- ✅ Lưu credentials vào local files (0600 permissions)
- ✅ Download Amazon Root CA1 certificate

#### **Deployment Module**: `dev/6.greengrass_core/`
- ✅ Thing registration: `GreengrassCore-site001-hanoi`
- ✅ Greengrass deployment configuration (IaC)
- ✅ Automated setup scripts
- ✅ Setup instructions documentation

### 2. AWS Resources Created

```
Thing Name:       GreengrassCore-site001-hanoi
Thing Type:       GreengrassCoreDevice
Thing Group:      Hanoi-Site-001
Policy:           aismc-dev-greengrass-core-policy
Certificate ARN:  arn:aws:iot:ap-southeast-1:061100493617:cert/13c7c3ba...
IoT Endpoint:     a3th3uw82ywkax-ats.iot.ap-southeast-1.amazonaws.com
Creds Endpoint:   cuw83h10f08ux.credentials.iot.ap-southeast-1.amazonaws.com
Region:           ap-southeast-1
```

### 3. Credentials Management

**SSM Parameters** (Encrypted):
```
/greengrass/GreengrassCore-site001-hanoi/cert-pem
/greengrass/GreengrassCore-site001-hanoi/private-key
/greengrass/GreengrassCore-site001-hanoi/public-key
```

**Local Files**:
```
dev/6.greengrass_core/greengrass-credentials/
├── GreengrassCore-site001-hanoi-certificate.pem.crt
├── GreengrassCore-site001-hanoi-private.pem.key
├── GreengrassCore-site001-hanoi-public.pem.key
└── AmazonRootCA1.pem
```

**Backup Created**:
```
/greengrass/v2/backup-20251231-144113/
├── thingCert.crt (old)
├── privKey.key (old)
└── rootCA.pem (old)
```

### 4. Greengrass Deployment

**Deployment Created**:
- Deployment ID: `f785530b-ea69-4365-bae2-8938c755f903`
- Deployment Name: `greengrass-core-config-dev-20251231074547`
- Status: `ACTIVE`
- Target: `GreengrassCore-site001-hanoi`

**Configuration**:
- ✅ Region: `ap-southeast-1` (changed from us-east-1)
- ✅ IoT Data Endpoint: `a3th3uw82ywkax-ats.iot.ap-southeast-1.amazonaws.com`
- ✅ IoT Creds Endpoint: `cuw83h10f08ux.credentials.iot.ap-southeast-1.amazonaws.com`
- ✅ IAM Role Alias: `GreengrassCoreTokenExchangeRoleAlias`

---

## ⚠️ VẤN ĐỀ CẦN GIẢI QUYẾT

### Issue: Thing Name Mismatch

**Hiện trạng**:
- Greengrass vẫn đang sử dụng Thing name cũ: `GreengrassCore-datht9`
- Thing mới đã tạo: `GreengrassCore-site001-hanoi`
- Credentials đã được copy nhưng Thing name chưa được update

**Nguyên nhân**:
- Greengrass được cài đặt ban đầu với Thing name `GreengrassCore-datht9`
- Configuration file của Greengrass vẫn reference Thing name cũ
- Deployment chỉ update Nucleus configuration, không update Thing name

**Impact**:
- Greengrass không thể kết nối tới AWS IoT Core (Thing name không khớp)
- Deployment không thể apply được configuration mới
- Components vẫn ở trạng thái BROKEN

---

## 🔧 BƯỚC TIẾP THEO

### Option 1: Re-provision Greengrass (Recommended)

Cài đặt lại Greengrass với Thing name mới:

```bash
# Stop Greengrass
sudo systemctl stop greengrass.service

# Backup current installation
sudo cp -r /greengrass/v2 /greengrass/v2.backup-full

# Remove old installation (keep backup)
sudo rm -rf /greengrass/v2/config
sudo rm -rf /greengrass/v2/deployments

# Run Greengrass installer with new configuration
sudo -E java -Droot="/greengrass/v2" \
  -Dlog.store=FILE \
  -jar /greengrass/v2/alts/current/distro/lib/Greengrass.jar \
  --aws-region ap-southeast-1 \
  --thing-name GreengrassCore-site001-hanoi \
  --thing-group-name Hanoi-Site-001 \
  --thing-policy-name aismc-dev-greengrass-core-policy \
  --tes-role-name GreengrassCoreTokenExchangeRole \
  --tes-role-alias-name GreengrassCoreTokenExchangeRoleAlias \
  --component-default-user ggc_user:ggc_group \
  --provision false \
  --deploy-dev-tools true
```

### Option 2: Manual Configuration Update

Update configuration files manually:

```bash
# Edit config
sudo nano /greengrass/v2/config/effectiveConfig.yaml

# Update thingName field:
services:
  aws.greengrass.Nucleus:
    configuration:
      thingName: "GreengrassCore-site001-hanoi"
      awsRegion: "ap-southeast-1"
      iotDataEndpoint: "a3th3uw82ywkax-ats.iot.ap-southeast-1.amazonaws.com"
      iotCredEndpoint: "cuw83h10f08ux.credentials.iot.ap-southeast-1.amazonaws.com"

# Restart
sudo systemctl restart greengrass.service
```

### Option 3: Terraform-managed Re-installation (Best Practice)

Create Terraform module to manage Greengrass installation:

```hcl
# dev/6.greengrass_core/greengrass-install.tf

resource "null_resource" "greengrass_reinstall" {
  provisioner "local-exec" {
    command = <<-EOT
      # Run installation script
      sudo ./install-greengrass.sh \
        --thing-name ${module.greengrass_core_hanoi_site_001.thing_name} \
        --region ${local.region} \
        --cert-path ${module.greengrass_core_hanoi_site_001.credentials_path}
    EOT
  }
}
```

---

## 📊 TERRAFORM STATE

**Resources Created**: 12 total
- 1 IoT Thing Type
- 1 IoT Thing  
- 1 IoT Certificate
- 1 Thing-Certificate Attachment
- 1 Policy Attachment
- 1 Thing Group Membership
- 3 SSM Parameters
- 3 Local Files

**Terraform Files**:
```
dev/6.greengrass_core/
├── main.tf                    (Thing registration)
├── deployment.tf              (Greengrass deployment)
├── provider.tf                (AWS provider config)
├── locals.tf                  (Local variables)
├── outputs.tf                 (Outputs)
├── terraform.tfstate          (Current state)
├── greengrass-deployment.json (Deployment config)
└── deployment-result.json     (Deployment result)
```

---

## 🎯 VERIFICATION COMMANDS

```bash
# Check Thing in AWS
aws iot describe-thing \
  --thing-name GreengrassCore-site001-hanoi \
  --region ap-southeast-1

# Check Deployment Status
aws greengrassv2 get-deployment \
  --deployment-id f785530b-ea69-4365-bae2-8938c755f903 \
  --region ap-southeast-1

# Check Greengrass Components
sudo /greengrass/v2/bin/greengrass-cli component list

# Check Logs
sudo tail -f /greengrass/v2/logs/greengrass.log
```

---

## 📝 LESSONS LEARNED

1. **Terraform cho Infrastructure là bắt buộc** - Mọi thay đổi phải được quản lý qua IaC
2. **Thing Name phải khớp** - Greengrass Thing name trong config phải match với Thing trên AWS
3. **Certificates không đủ** - Copy certificates mới không tự động update Thing name
4. **Backup quan trọng** - Luôn backup trước khi thay đổi
5. **AWS Provider Limitations** - Một số resources (như greengrassv2_deployment) chưa được hỗ trợ, cần dùng null_resource + AWS CLI

---

## ✅ SUCCESS CRITERIA

Để hoàn thành Giai đoạn 1, cần đạt được:

- [x] Thing mới được tạo trên AWS IoT Core
- [x] Certificates được generate và attach
- [x] Credentials được backup an toàn
- [x] Deployment configuration được tạo qua IaC
- [ ] Greengrass kết nối thành công với Thing mới
- [ ] Tất cả components ở trạng thái RUNNING
- [ ] Không còn DNS resolution errors

---

**Next Action**: Choose Option 1 (Re-provision) và thực hiện reinstall Greengrass với Thing name mới.

