# Zabbix Integration Module

**Version**: 1.0.0
**Status**: ✅ IaC Compliant
**Last Updated**: 2026-01-02

---

## 📁 Cấu Trúc Thư Mục

```
zabbix-integration/
├── README.md                         # File này
├── IaC_RULES_ANALYSIS.md            # Phân tích IaC compliance
│
├── terraform/                        # Terraform configurations
│   └── zabbix-webhook-fixes.tf      # Webhook deployment resources
│
├── scripts/                          # Deployment & testing scripts
│   ├── verify-webhook.sh            # Webhook verification script
│   └── zabbix-webhook-setup.sh      # Zabbix setup script
│
├── docs/                            # Documentation
│   ├── IAC_WEBHOOK_DEPLOYMENT_COMPLETE.md
│   ├── ZABBIX_INTEGRATION_STATUS.md
│   ├── ZABBIX_WEBHOOK_INTEGRATION_SUMMARY.md
│   └── ZABBIX_WEBHOOK_SETUP.md
│
└── templates/                       # Configuration templates
    └── (future webhook config templates)
```

---

## 🎯 Mục Đích

Module này quản lý tích hợp Zabbix với AWS Greengrass để:
1. Nhận webhook events từ Zabbix khi camera offline/online
2. Lưu trữ incidents vào SQLite database
3. Tự động tạo camera record nếu chưa tồn tại
4. Đồng bộ dữ liệu lên AWS IoT Core/DynamoDB

---

## 🚀 Deployment

### Prerequisites

- Terraform đã cài đặt
- AWS CLI configured với credentials
- Zabbix 7.4.5 đang chạy trên localhost:8080
- Greengrass v2 đã cài đặt

### Deployment Steps

```bash
# 1. Di chuyển vào thư mục terraform
cd /home/sysadmin/2025/aismc/aws-aiops/dev/6.greengrass_core

# 2. Validate Terraform
terraform validate

# 3. Plan deployment
terraform plan -out=tfplan-zabbix-integration

# 4. Review plan
terraform show tfplan-zabbix-integration

# 5. Apply (sau khi user approve)
terraform apply tfplan-zabbix-integration

# 6. Verify deployment
curl -s http://localhost:8081/health | python3 -m json.tool
```

---

## 📋 Terraform Resources

### `zabbix-webhook-fixes.tf`

#### Resources Created:

1. **`null_resource.install_fping`**
   - Install fping package for Zabbix ICMP checks
   - Set setuid permission
   - Create symlink `/usr/sbin/fping` → `/usr/bin/fping`
   - **Trigger**: `install_version = "fping_v1"`

2. **`null_resource.deploy_webhook_fixes`**
   - Deploy updated `webhook_server.py` with camera auto-creation
   - Deploy updated `dao.py` with optional ngsi_ld field
   - Restart Greengrass service
   - **Triggers**:
     - `webhook_server_md5` = MD5 of webhook_server.py
     - `dao_md5` = MD5 of dao.py

3. **`null_resource.verify_webhook_fixes`**
   - Verify webhook endpoint health
   - Check Greengrass component status
   - Verify webhook server process

4. **`null_resource.restart_zabbix_server`**
   - Restart Zabbix server to clear configuration cache
   - Verify Zabbix server status

#### Outputs:

- `webhook_fixes_status` - Deployment status summary
- `webhook_verification_command` - Health check command
- `webhook_test_command` - Test webhook command
- `webhook_logs_command` - View logs command
- `database_check_command` - Database query command

---

## 🧪 Testing

### 1. Health Check

```bash
curl -s http://localhost:8081/health | python3 -m json.tool
```

**Expected Output**:
```json
{
  "status": "healthy",
  "component": "ZabbixEventSubscriber",
  "version": "1.0.0",
  "database": {
    "status": "healthy",
    "cameras": 2,
    "incidents": 3,
    "integrity": "ok"
  }
}
```

### 2. Test Webhook with Sample Payload

```bash
./scripts/verify-webhook.sh
```

### 3. Check Database

```bash
sudo -u ggc_user sqlite3 /var/greengrass/database/greengrass.db \
  "SELECT incident_id, camera_id, incident_type, severity, detected_at
   FROM incidents
   ORDER BY detected_at DESC
   LIMIT 5;"
```

### 4. View Logs

```bash
sudo tail -f /greengrass/v2/logs/com.aismc.ZabbixEventSubscriber.log
```

---

## 🔧 Configuration

### Zabbix Media Type

- **Name**: Greengrass Webhook
- **Type**: Webhook
- **Endpoint**: `http://localhost:8081/zabbix/events`
- **Parameters**: 10 parameters (event_id, host_name, etc.)

### Zabbix Action

- **Name**: Camera Events to Greengrass
- **Trigger**: Severity >= High (4)
- **Operation**: Send to Admin via Greengrass Webhook

### Greengrass Component

- **Component**: com.aismc.ZabbixEventSubscriber
- **Version**: 1.0.0
- **Port**: 8081
- **Database**: `/var/greengrass/database/greengrass.db`

---

## 🐛 Troubleshooting

### Issue: Webhook Returns 500 Error

**Cause**: Camera không tồn tại trong database và ngsi_ld field missing

**Fix**: ✅ **FIXED** - Camera auto-creation logic đã được thêm

### Issue: fping Not Found

**Cause**: fping chưa được cài đặt

**Fix**: ✅ **FIXED** - Terraform tự động cài fping với setuid permission

### Issue: Macros Not Expanding

**Status**: 🔴 **BLOCKER** - Zabbix 7.4.5 gửi literal macro strings

**Workaround**: Test với manual payloads (không dùng macros)

**Next Steps**: Debug Zabbix webhook macro expansion

---

## 📊 IaC Compliance

### ✅ Compliant Practices

- ✅ All infrastructure via Terraform
- ✅ Source code in `edge-components/` (version controlled)
- ✅ MD5 triggers for automatic redeployment
- ✅ No manual file edits to deployed code
- ✅ Service restarts via Terraform provisioners
- ✅ Proper documentation

### ⚠️ Previous Violations (Now Fixed)

- ❌ Manual `apt-get install fping` → ✅ Terraform provisioner
- ❌ Manual file edits → ✅ Source updates + terraform apply
- ❌ Manual service restarts → ✅ Terraform provisioner

---

## 🔄 Maintenance

### Redeployment When Source Changes

Terraform tự động detect thay đổi qua MD5 triggers:

```bash
# 1. Edit source files
vi /home/sysadmin/2025/aismc/aws-aiops/dev/6.greengrass_core/edge-components/zabbix-event-subscriber/src/webhook_server.py

# 2. Terraform sẽ tự động phát hiện thay đổi
terraform plan

# 3. Apply changes
terraform apply
```

### Manual Redeploy

```bash
# Taint resource để force recreation
terraform taint null_resource.deploy_webhook_fixes

# Re-apply
terraform apply
```

---

## 📚 Related Documentation

- **IaC Rules**: `/home/sysadmin/2025/aismc/aws-aiops/.claude/rules`
- **Must Read First**: `/home/sysadmin/2025/aismc/aws-aiops/.claude/MUST_READ_FIRST.md`
- **Full Deployment**: `docs/IAC_WEBHOOK_DEPLOYMENT_COMPLETE.md`
- **Integration Summary**: `docs/ZABBIX_WEBHOOK_INTEGRATION_SUMMARY.md`

---

## 🎯 Next Steps

### Priority 1: Debug Macro Expansion (BLOCKER)
- [ ] Check Zabbix server logs during webhook execution
- [ ] Test different webhook script configurations
- [ ] Verify Zabbix 7.4.5 parameter handling
- [ ] Consider JavaScript preprocessing in webhook script

### Priority 2: End-to-End Testing
- [ ] Trigger real Zabbix alert by disconnecting camera
- [ ] Verify webhook receives expanded macros
- [ ] Confirm incident stored with correct data
- [ ] Test recovery flow
- [ ] Verify analytics aggregation
- [ ] Confirm sync to DynamoDB

### Priority 3: Monitoring
- [ ] Set up CloudWatch alarms for webhook errors
- [ ] Monitor database growth
- [ ] Track sync failures
- [ ] Create dashboard for incident metrics

---

## 🤝 Contributing

Khi thêm features hoặc fixes:

1. ✅ **LUÔN** dùng Terraform
2. ✅ Cập nhật source trong `edge-components/`
3. ✅ Thêm MD5 triggers cho files mới
4. ✅ Update documentation
5. ✅ Test trước khi commit
6. ✅ Follow git commit standards

---

## 📞 Support

Nếu gặp vấn đề:

1. Kiểm tra logs: `sudo tail -f /greengrass/v2/logs/com.aismc.ZabbixEventSubscriber.log`
2. Verify health: `curl http://localhost:8081/health`
3. Check database: `sqlite3 /var/greengrass/database/greengrass.db`
4. Review Terraform state: `terraform state list`

---

**Maintained By**: Infrastructure as Code (Terraform)
**Version**: 1.0.0
**Last Updated**: 2026-01-02

