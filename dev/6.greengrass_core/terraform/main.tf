terraform {
  required_version = ">= 1.5.0"

  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
    }
    local = {
      source  = "hashicorp/local"
      version = "~> 2.0"
    }
    null = {
      source  = "hashicorp/null"
      version = "~> 3.0"
    }
  }

  # Backend configuration - uncomment after first apply
  # backend "s3" {
  #   bucket         = "aismc-platform-terraformstatefile-20251101-061100493617"
  #   key            = "dev/greengrass-core/terraform.tfstate"
  #   region         = "ap-southeast-1"
  #   encrypt        = true
  #   dynamodb_table = "terraform-state-lock"
  # }
}

# ============================================================================
# Greengrass Core Thing Registration
# ============================================================================
# This creates IoT Things for Greengrass Core devices at each site
# Currently deploying: Hanoi Site 001 (Pilot)
# ============================================================================

# Reference existing IoT Policy and Thing Group names
# These are created by dev/2.iot_core module
locals {
  greengrass_policy_name = "aismc-dev-greengrass-core-policy"
  hanoi_site_thing_group = "Hanoi-Site-001"
}

# ============================================================================
# Greengrass Core Thing for Hanoi Site 001
# ============================================================================

module "greengrass_core_hanoi_site_001" {
  source = "../../_module/aws/iot/greengrass_thing"

  thing_name       = "GreengrassCore-site001-hanoi"
  policy_name      = local.greengrass_policy_name
  thing_group_name = local.hanoi_site_thing_group

  attributes = {
    site_id      = "site-001"
    site_name    = "Hanoi-Pilot-Site"
    location     = "Hanoi"
    environment  = local.environment
    camera_count = "15000"
    device_type  = "GreengrassCore"
  }

  # Save credentials locally for initial Greengrass setup
  save_credentials_locally = true
  credentials_output_path  = "${path.module}/greengrass-credentials"

  tags = merge(local.tags, {
    SiteId   = "site-001"
    SiteName = "Hanoi-Pilot-Site"
  })
}

# ============================================================================
# Output credentials information for setup
# ============================================================================

# Create setup instructions file
resource "local_file" "setup_instructions" {
  content = templatefile("${path.module}/templates/setup-instructions.tpl", {
    thing_name        = module.greengrass_core_hanoi_site_001.thing_name
    iot_endpoint      = module.greengrass_core_hanoi_site_001.iot_endpoint
    credentials_path  = module.greengrass_core_hanoi_site_001.credentials_path
    thing_group       = local.hanoi_site_thing_group
    region            = local.region
    cert_arn          = module.greengrass_core_hanoi_site_001.certificate_arn
    ssm_cert_param    = module.greengrass_core_hanoi_site_001.ssm_cert_parameter
    ssm_key_param     = module.greengrass_core_hanoi_site_001.ssm_private_key_parameter
  })

  filename        = "${path.module}/GREENGRASS-SETUP-INSTRUCTIONS.md"
  file_permission = "0644"
}

# Create script to copy credentials to Greengrass directory
resource "local_file" "copy_credentials_script" {
  content = templatefile("${path.module}/templates/copy-credentials.sh.tpl", {
    thing_name       = module.greengrass_core_hanoi_site_001.thing_name
    credentials_path = module.greengrass_core_hanoi_site_001.credentials_path
  })

  filename        = "${path.module}/copy-credentials-to-greengrass.sh"
  file_permission = "0755"
}
