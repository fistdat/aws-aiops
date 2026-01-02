#!/bin/bash
# Claude Startup Reminder Script
# Purpose: Nhắc nhở IaC rules trước mỗi session
# Version: 1.0.0

cat << 'EOF'
╔═══════════════════════════════════════════════════════════════════════╗
║                    AWS AIOps Project - IaC Rules Active               ║
╠═══════════════════════════════════════════════════════════════════════╣
║                                                                       ║
║  ✅ 100% Infrastructure as Code Compliance REQUIRED                   ║
║  ✅ All changes MUST use Terraform                                    ║
║  ✅ No manual commands without Terraform provisioners                 ║
║                                                                       ║
╠═══════════════════════════════════════════════════════════════════════╣
║  📋 LUỒNG CÔNG VIỆC BẮT BUỘC:                                         ║
║                                                                       ║
║  1. Acknowledge → "Tôi sẽ dùng Terraform để tuân thủ IaC"            ║
║  2. Design      → Giải thích Terraform approach                      ║
║  3. Implement   → Viết Terraform code                                ║
║  4. Validate    → terraform validate                                 ║
║  5. Plan        → terraform plan -out=tfplan                         ║
║  6. Approval    → Xin phép user                                      ║
║  7. Apply       → terraform apply tfplan                             ║
║  8. Verify      → Kiểm tra deployment                                ║
║  9. Document    → Cập nhật tài liệu                                  ║
║                                                                       ║
╠═══════════════════════════════════════════════════════════════════════╣
║  ❌ CẤM TUYỆT ĐỐI:                                                     ║
║                                                                       ║
║  ❌ sudo apt-get install <package>                                    ║
║  ❌ sudo vi /path/to/deployed/file                                    ║
║  ❌ sudo systemctl restart <service>                                  ║
║  ❌ aws iot create-thing ...                                          ║
║                                                                       ║
║  ✅ Phải dùng Terraform null_resource provisioner                     ║
║  ✅ Update source trong edge-components/ + terraform apply           ║
║                                                                       ║
╠═══════════════════════════════════════════════════════════════════════╣
║  📚 DOCUMENTATION:                                                    ║
║                                                                       ║
║  • Full Rules:      .claude/rules (762 dòng)                         ║
║  • Must Read:       .claude/MUST_READ_FIRST.md                       ║
║  • Quick Ref:       .claude/QUICK-REFERENCE.md                       ║
║                                                                       ║
╚═══════════════════════════════════════════════════════════════════════╝

EOF

echo ""
echo "📌 Paste nội dung sau vào prompt để nhắc Claude:"
echo ""
echo "\"Đọc /home/sysadmin/2025/aismc/aws-aiops/.claude/MUST_READ_FIRST.md và tuân thủ 100% IaC theo Section 15.1\""
echo ""
