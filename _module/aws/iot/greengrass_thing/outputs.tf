# ============================================================================
# Outputs for Greengrass Thing Module
# ============================================================================

output "thing_name" {
  description = "Name of the created IoT Thing"
  value       = aws_iot_thing.greengrass_core.name
}

output "thing_arn" {
  description = "ARN of the created IoT Thing"
  value       = aws_iot_thing.greengrass_core.arn
}

output "thing_id" {
  description = "ID of the created IoT Thing"
  value       = aws_iot_thing.greengrass_core.id
}

output "certificate_arn" {
  description = "ARN of the IoT Certificate"
  value       = aws_iot_certificate.greengrass_cert.arn
}

output "certificate_id" {
  description = "ID of the IoT Certificate"
  value       = aws_iot_certificate.greengrass_cert.id
}

output "certificate_pem" {
  description = "PEM-encoded certificate (sensitive)"
  value       = aws_iot_certificate.greengrass_cert.certificate_pem
  sensitive   = true
}

output "private_key" {
  description = "PEM-encoded private key (sensitive)"
  value       = aws_iot_certificate.greengrass_cert.private_key
  sensitive   = true
}

output "public_key" {
  description = "PEM-encoded public key (sensitive)"
  value       = aws_iot_certificate.greengrass_cert.public_key
  sensitive   = true
}

output "iot_endpoint" {
  description = "AWS IoT data endpoint for this region"
  value       = data.aws_iot_endpoint.data_ats.endpoint_address
}

output "ssm_cert_parameter" {
  description = "SSM Parameter name for certificate"
  value       = aws_ssm_parameter.cert_pem.name
}

output "ssm_private_key_parameter" {
  description = "SSM Parameter name for private key"
  value       = aws_ssm_parameter.private_key.name
}

output "credentials_path" {
  description = "Local path where credentials are saved"
  value       = var.save_credentials_locally ? var.credentials_output_path : null
}

# Data source to get IoT endpoint
data "aws_iot_endpoint" "data_ats" {
  endpoint_type = "iot:Data-ATS"
}
