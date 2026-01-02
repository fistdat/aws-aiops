# ⚠️ BẮT BUỘC ĐỌC TRƯỚC KHI BẮT ĐẦU MỖI SESSION

---

## 🎯 NGUYÊN TẮC VÀNG - 100% IaC

> **NẾU THAY ĐỔI INFRASTRUCTURE/CONFIG/DEPLOYMENT → BẮT BUỘC DÙNG TERRAFORM**

**Không có ngoại lệ** trừ khi user phê duyệt rõ ràng.

---

## 📋 LUỒNG CÔNG VIỆC BẮT BUỘC (Section 15.1)

### Khi User Yêu Cầu Thay Đổi Infrastructure:

```
┌─────────────────────────────────────────────────────────────┐
│ 1. ACKNOWLEDGE (Ngay lập tức)                              │
│    "Tôi sẽ triển khai qua Terraform để tuân thủ IaC"       │
├─────────────────────────────────────────────────────────────┤
│ 2. DESIGN (Giải thích cách dùng Terraform)                 │
│    - Terraform resources cần tạo                            │
│    - Files cần modify                                       │
│    - Triggers (MD5 hashing)                                 │
├─────────────────────────────────────────────────────────────┤
│ 3. IMPLEMENT (Viết Terraform code)                         │
│    - Tạo/cập nhật *.tf files                               │
│    - Cập nhật source code trong edge-components/           │
├─────────────────────────────────────────────────────────────┤
│ 4. VALIDATE                                                 │
│    terraform validate                                       │
├─────────────────────────────────────────────────────────────┤
│ 5. PLAN                                                     │
│    terraform plan -out=tfplan-{descriptive-name}           │
├─────────────────────────────────────────────────────────────┤
│ 6. REQUEST APPROVAL (Xin phép user)                        │
│    "Plan đã sẵn sàng. Cho phép terraform apply?"           │
├─────────────────────────────────────────────────────────────┤
│ 7. APPLY (Sau khi user đồng ý)                             │
│    terraform apply tfplan-{descriptive-name}               │
├─────────────────────────────────────────────────────────────┤
│ 8. VERIFY (Kiểm tra deployment)                            │
│    - Health checks                                          │
│    - Functional tests                                       │
├─────────────────────────────────────────────────────────────┤
│ 9. DOCUMENT (Cập nhật tài liệu)                            │
│    - README.md                                              │
│    - Deployment summary                                     │
└─────────────────────────────────────────────────────────────┘
```

---

## ❌ CẤM TUYỆT ĐỐI

### KHÔNG BAO GIỜ làm những việc này trực tiếp:

```bash
# ❌ Package Installation
sudo apt-get install <package>
sudo yum install <package>
pip install <package>
```
✅ **Phải dùng**: Terraform `null_resource` provisioner

```bash
# ❌ File Editing
sudo vi /path/to/deployed/file
sudo nano /greengrass/v2/components/...
```
✅ **Phải dùng**: Update source trong `edge-components/`, sau đó terraform apply

```bash
# ❌ Service Management
sudo systemctl restart <service>
sudo systemctl reload <service>
```
✅ **Phải dùng**: Terraform provisioner với proper triggers

```bash
# ❌ Permission Changes
sudo chmod 755 /path/to/file
sudo chown user:group /path/to/file
```
✅ **Phải dùng**: Terraform provisioner script

```bash
# ❌ AWS Resource Creation
aws iot create-thing --thing-name ...
aws dynamodb create-table ...
```
✅ **Phải dùng**: Terraform `aws_iot_thing`, `aws_dynamodb_table` resources

---

## ✅ ĐƯỢC PHÉP (Read-Only Operations)

### Các lệnh KHÔNG cần Terraform:

```bash
# ✅ AWS CLI Queries (chỉ đọc)
aws iot list-things
aws dynamodb describe-table
aws logs tail /aws/lambda/function

# ✅ System Queries
systemctl status <service>
ls -la /path
cat /var/log/file

# ✅ Database Queries (SELECT only)
sqlite3 database.db "SELECT * FROM table;"

# ✅ Testing
curl http://localhost:8081/health
python3 ./tests/test_component.py

# ✅ Debugging
tail -f /greengrass/v2/logs/component.log
journalctl -u greengrass -f
```

---

## 📝 TEMPLATE RESPONSE BẮT BUỘC

### Khi User Yêu Cầu Infrastructure Change:

```markdown
Tôi hiểu yêu cầu: {tóm tắt yêu cầu của user}

Để tuân thủ 100% IaC compliance, tôi sẽ triển khai qua Terraform:

📋 **Terraform Resources**:
1. {resource_type}.{name} - {mục đích}
2. {resource_type}.{name} - {mục đích}

📁 **Files Cần Modify**:
- {module}/{file}.tf
- {component}/src/{source_file}

🔄 **Deployment Triggers**:
- MD5 change detection cho source files
- Auto-redeploy khi files thay đổi

✅ **IaC Compliance**: 100%

Cho phép tôi tiếp tục với terraform validate?
```

---

## 🚨 NGOẠI LỆ DUY NHẤT (Section 14.1)

### Khi ĐƯỢC PHÉP manual operation:

1. **Emergency Production Fix** (outage)
   - User phải approve rõ ràng
   - PHẢI document ngay
   - PHẢI reconcile với Terraform trong 24h

2. **User Yêu Cầu Rõ Ràng**
   - User nói: "manually install X for testing"
   - VẪN PHẢI recommend Terraform approach trước

### Response Template cho Ngoại Lệ:

```markdown
⚠️ User yêu cầu manual operation: {operation}

Tôi khuyến nghị cách IaC-compliant:
{terraform approach}

Tuy nhiên, nếu user muốn proceed manual:
- [ ] Tôi sẽ thực hiện manual
- [ ] Document tất cả changes
- [ ] Tạo reconciliation plan
- [ ] Migrate to Terraform sau

User có muốn proceed với manual approach?
```

---

## 🎓 QUY TẮC VỀ MD5 TRIGGERS

### BẮT BUỘC cho mọi file deployment:

```hcl
resource "null_resource" "deploy_component" {
  triggers = {
    # Source code files
    main_code_md5    = filemd5("path/to/main.py")
    config_md5       = filemd5("path/to/config.json")

    # Scripts
    setup_script_md5 = filemd5("path/to/setup.sh")

    # Dependencies
    requirements_md5 = filemd5("path/to/requirements.txt")

    # Schema/Config
    schema_md5       = filemd5("path/to/schema.sql")
  }

  provisioner "local-exec" {
    command = <<-EOT
      # Deployment commands
    EOT
  }
}
```

**File types cần triggers**:
- ✅ Python/Node.js source (*.py, *.js)
- ✅ Shell scripts (*.sh)
- ✅ SQL schemas (*.sql)
- ✅ Config files (*.json, *.yaml, *.conf)
- ✅ Templates (*.tpl)
- ✅ Requirements (requirements.txt, package.json)

---

## 📊 CHECKLIST TRƯỚC KHI HOÀN THÀNH TASK

- [ ] Tất cả changes qua Terraform (không manual)
- [ ] `terraform validate` pass
- [ ] `terraform plan` đã review với user
- [ ] `terraform apply` thành công
- [ ] Triggers đã configure đúng (MD5 hashing)
- [ ] Resources có đúng tags
- [ ] File permissions đúng (ggc_user ownership)
- [ ] Không hardcode secrets
- [ ] Documentation đã update (README, summary)
- [ ] Verification tests pass
- [ ] State file in S3 backend
- [ ] Không có manual edits to deployed files
- [ ] Git commit message theo chuẩn

---

## 🔗 QUICK LINKS

- **Full Rules**: `.claude/rules` (762 dòng)
- **Quick Reference**: `.claude/QUICK-REFERENCE.md`
- **Project Structure**: `dev/6.greengrass_core/`
- **Modules**: `_module/aws/`
- **Docs**: `claudedocs/`

---

## 📌 GHI NHỚ

```
┌─────────────────────────────────────────────────────┐
│  "If it changes infrastructure, configuration,     │
│   or deployment, it MUST go through Terraform."    │
│                                                     │
│  No exceptions without explicit user approval.     │
└─────────────────────────────────────────────────────┘
```

### Lợi ích 100% IaC:
- ✅ Reproducible deployments
- ✅ Version controlled infrastructure
- ✅ No configuration drift
- ✅ Easy rollback
- ✅ Audit trail
- ✅ Disaster recovery ready

---

**Khi nghi ngờ**: Chọn Terraform thay vì manual commands. **Luôn luôn**.

---

**Version**: 1.0.0
**Last Updated**: 2026-01-02
**Compliance Level**: 100% IaC Required

