# ============================================================================
# Outputs for Greengrass Core Deployment
# ============================================================================

output "thing_name" {
  description = "Name of the Greengrass Core Thing"
  value       = module.greengrass_core_hanoi_site_001.thing_name
}

output "thing_arn" {
  description = "ARN of the Greengrass Core Thing"
  value       = module.greengrass_core_hanoi_site_001.thing_arn
}

output "certificate_arn" {
  description = "ARN of the IoT Certificate"
  value       = module.greengrass_core_hanoi_site_001.certificate_arn
}

output "certificate_id" {
  description = "ID of the IoT Certificate"
  value       = module.greengrass_core_hanoi_site_001.certificate_id
}

output "iot_endpoint" {
  description = "AWS IoT Core endpoint for this region"
  value       = module.greengrass_core_hanoi_site_001.iot_endpoint
}

output "credentials_path" {
  description = "Local path where credentials are saved"
  value       = module.greengrass_core_hanoi_site_001.credentials_path
}

output "ssm_cert_parameter" {
  description = "SSM Parameter name for certificate"
  value       = module.greengrass_core_hanoi_site_001.ssm_cert_parameter
}

output "ssm_private_key_parameter" {
  description = "SSM Parameter name for private key"
  value       = module.greengrass_core_hanoi_site_001.ssm_private_key_parameter
}

output "setup_instructions_file" {
  description = "Path to setup instructions file"
  value       = "${path.module}/GREENGRASS-SETUP-INSTRUCTIONS.md"
}

output "copy_credentials_script" {
  description = "Path to script for copying credentials to Greengrass"
  value       = "${path.module}/copy-credentials-to-greengrass.sh"
}

# ============================================================================
# Sensitive Outputs (use terraform output -json to view)
# ============================================================================

output "certificate_pem" {
  description = "Certificate PEM (sensitive - use for initial setup only)"
  value       = module.greengrass_core_hanoi_site_001.certificate_pem
  sensitive   = true
}

output "private_key" {
  description = "Private key (sensitive - use for initial setup only)"
  value       = module.greengrass_core_hanoi_site_001.private_key
  sensitive   = true
}

# ============================================================================
# Quick Setup Summary
# ============================================================================

output "setup_summary" {
  description = "Quick setup summary"
  value = <<-EOT

  ================================================================
  🚀 Greengrass Core Thing Created Successfully!
  ================================================================

  Thing Name:    ${module.greengrass_core_hanoi_site_001.thing_name}
  Thing Group:   Hanoi-Site-001
  IoT Endpoint:  ${module.greengrass_core_hanoi_site_001.iot_endpoint}
  Region:        ap-southeast-1

  📁 Credentials saved to:
     ${module.greengrass_core_hanoi_site_001.credentials_path}/

  📝 Next Steps:

  1. Read setup instructions:
     cat ${path.module}/GREENGRASS-SETUP-INSTRUCTIONS.md

  2. Copy credentials to Greengrass:
     sudo ${path.module}/copy-credentials-to-greengrass.sh

  3. Reconfigure Greengrass Core:
     See GREENGRASS-SETUP-INSTRUCTIONS.md for details

  ================================================================
  EOT
}
