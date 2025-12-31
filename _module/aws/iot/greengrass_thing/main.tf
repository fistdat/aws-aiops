# ============================================================================
# AWS IoT Greengrass Thing Module
# ============================================================================
# This module creates an IoT Thing for Greengrass Core device with:
# - Thing registration
# - Certificate creation and attachment
# - Policy attachment
# - Thing Group membership
# ============================================================================

# Create IoT Thing Type for Greengrass Core
resource "aws_iot_thing_type" "greengrass_core_type" {
  name = "GreengrassCoreDevice"

  properties {
    description               = "Thing type for AWS IoT Greengrass Core devices"
    searchable_attributes     = ["site_id", "location", "environment"]
  }
}

# Create IoT Thing for Greengrass Core
resource "aws_iot_thing" "greengrass_core" {
  name       = var.thing_name
  thing_type_name = aws_iot_thing_type.greengrass_core_type.name

  attributes = var.attributes

  depends_on = [aws_iot_thing_type.greengrass_core_type]
}

# Create IoT Certificate and Keys
resource "aws_iot_certificate" "greengrass_cert" {
  active = true
}

# Attach Certificate to Thing
resource "aws_iot_thing_principal_attachment" "greengrass_cert_attachment" {
  principal = aws_iot_certificate.greengrass_cert.arn
  thing     = aws_iot_thing.greengrass_core.name
}

# Attach Policy to Certificate
resource "aws_iot_policy_attachment" "greengrass_policy_attachment" {
  policy = var.policy_name
  target = aws_iot_certificate.greengrass_cert.arn
}

# Add Thing to Thing Group
resource "aws_iot_thing_group_membership" "greengrass_group_membership" {
  thing_name       = aws_iot_thing.greengrass_core.name
  thing_group_name = var.thing_group_name

  override_dynamic_group = false
}

# Store certificate in SSM Parameter Store for secure access
resource "aws_ssm_parameter" "cert_pem" {
  name        = "/greengrass/${var.thing_name}/cert-pem"
  description = "IoT Certificate PEM for ${var.thing_name}"
  type        = "SecureString"
  value       = aws_iot_certificate.greengrass_cert.certificate_pem

  tags = var.tags
}

resource "aws_ssm_parameter" "private_key" {
  name        = "/greengrass/${var.thing_name}/private-key"
  description = "IoT Private Key for ${var.thing_name}"
  type        = "SecureString"
  value       = aws_iot_certificate.greengrass_cert.private_key

  tags = var.tags
}

resource "aws_ssm_parameter" "public_key" {
  name        = "/greengrass/${var.thing_name}/public-key"
  description = "IoT Public Key for ${var.thing_name}"
  type        = "SecureString"
  value       = aws_iot_certificate.greengrass_cert.public_key

  tags = var.tags
}

# Save credentials to local files (for initial Greengrass setup)
resource "local_file" "certificate_pem" {
  count = var.save_credentials_locally ? 1 : 0

  content         = aws_iot_certificate.greengrass_cert.certificate_pem
  filename        = "${var.credentials_output_path}/${var.thing_name}-certificate.pem.crt"
  file_permission = "0600"
}

resource "local_file" "private_key" {
  count = var.save_credentials_locally ? 1 : 0

  content         = aws_iot_certificate.greengrass_cert.private_key
  filename        = "${var.credentials_output_path}/${var.thing_name}-private.pem.key"
  file_permission = "0600"
}

resource "local_file" "public_key" {
  count = var.save_credentials_locally ? 1 : 0

  content         = aws_iot_certificate.greengrass_cert.public_key
  filename        = "${var.credentials_output_path}/${var.thing_name}-public.pem.key"
  file_permission = "0600"
}

# Download Amazon Root CA
resource "null_resource" "download_root_ca" {
  count = var.save_credentials_locally ? 1 : 0

  provisioner "local-exec" {
    command = <<-EOT
      curl -o ${var.credentials_output_path}/AmazonRootCA1.pem \
        https://www.amazontrust.com/repository/AmazonRootCA1.pem
    EOT
  }

  depends_on = [
    local_file.certificate_pem,
    local_file.private_key
  ]
}
