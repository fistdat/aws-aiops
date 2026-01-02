# IaC Quick Reference Card

**Project**: AWS AIOps
**IaC Tool**: Terraform
**Compliance Level**: 100% - No Manual Changes

---

## ⚡ Quick Commands

### Terraform Workflow
```bash
# Standard workflow for ANY change
terraform validate
terraform plan -out=tfplan
terraform apply tfplan

# Force resource recreation
terraform taint {resource_type}.{name}
terraform apply

# Import existing resource
terraform import {resource_type}.{name} {aws_resource_id}
```

### Verification
```bash
# Check deployment
terraform plan  # Should show "No changes"

# Test components
sudo python3 ./edge-components/scripts/test-database.py

# View database
sudo -u ggc_user sqlite3 /var/greengrass/database/greengrass.db
```

---

## 🚫 DON'T DO THIS

| ❌ Manual Command | ✅ IaC Approach |
|-------------------|----------------|
| `sudo apt-get install sqlite3` | Add to Terraform `null_resource` provisioner |
| `aws iot create-thing` | Use Terraform `aws_iot_thing` resource |
| `sudo chmod 755 script.sh` | Add to Terraform provisioner script |
| `cp file.py /greengrass/` | Use Terraform `local_file` + provisioner |
| Edit deployed file directly | Edit source file, `terraform apply` |

---

## 📁 Key Directories

```
dev/6.greengrass_core/           # Current work
├── edge-components.tf           # Main Terraform config
├── edge-components/             # Source files
│   ├── database/schema.sql     # Database schema
│   ├── python-dao/*.py         # DAO layer
│   └── scripts/*.sh            # Setup scripts
└── templates/*.tpl             # Documentation templates
```

---

## 🔧 Common Tasks

### Add New Package Installation
```hcl
resource "null_resource" "install_package" {
  triggers = {
    version = "v1.0.0"
  }

  provisioner "local-exec" {
    command = <<-EOT
      sudo apt-get update
      sudo apt-get install -y package-name
    EOT
  }
}
```

### Deploy New File
```hcl
resource "null_resource" "deploy_file" {
  triggers = {
    file_md5 = filemd5("source/file.py")
  }

  provisioner "local-exec" {
    command = <<-EOT
      sudo cp source/file.py /target/location/
      sudo chown ggc_user:ggc_group /target/location/file.py
    EOT
  }
}
```

### Add File Change Detection
```hcl
triggers = {
  script_md5 = filemd5("path/to/script.sh")
  config_md5 = filemd5("path/to/config.json")
}
```

---

## 🎯 Remember

**Golden Rule**: If it changes infrastructure → Use Terraform

**Before completing any task**:
- [ ] Terraform validate ✅
- [ ] Terraform plan reviewed ✅
- [ ] User approved ✅
- [ ] Terraform apply successful ✅
- [ ] Tests passed ✅
- [ ] Documentation updated ✅

---

**Full Rules**: See `.claude/rules` file
