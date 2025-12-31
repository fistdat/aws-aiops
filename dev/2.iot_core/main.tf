terraform {
  required_version = ">= 1.5.0"

  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
    }
  }

  # Uncomment after first apply to enable remote state
  # backend "s3" {
  #   bucket         = "aismc-nonprod-terraform-state"
  #   key            = "dev/iot-core/terraform.tfstate"
  #   region         = "ap-southeast-1"
  #   encrypt        = true
  #   dynamodb_table = "terraform-state-lock"
  # }
}

# ============================================================================
# Thing Groups Hierarchy: Vietnam → Regions → Sites
# ============================================================================

# Root Thing Group: Vietnam
module "vietnam_thing_group" {
  source = "../../_module/aws/iot/thing_group"

  thing_group_name = "Vietnam"
  description      = "Root Thing Group for all Vietnam sites"

  attributes = {
    country     = "Vietnam"
    total_sites = "20"
  }

  tags = local.tags
}

# Regional Thing Groups
module "northern_region_thing_group" {
  source = "../../_module/aws/iot/thing_group"

  thing_group_name  = "Northern-Region"
  parent_group_name = module.vietnam_thing_group.thing_group_name
  description       = "Northern Region (Hanoi, Hai Phong)"

  attributes = {
    region = "northern"
  }

  tags = local.tags

  depends_on = [module.vietnam_thing_group]
}

module "central_region_thing_group" {
  source = "../../_module/aws/iot/thing_group"

  thing_group_name  = "Central-Region"
  parent_group_name = module.vietnam_thing_group.thing_group_name
  description       = "Central Region (Da Nang, Hue)"

  attributes = {
    region = "central"
  }

  tags = local.tags

  depends_on = [module.vietnam_thing_group]
}

module "southern_region_thing_group" {
  source = "../../_module/aws/iot/thing_group"

  thing_group_name  = "Southern-Region"
  parent_group_name = module.vietnam_thing_group.thing_group_name
  description       = "Southern Region (HCMC, Can Tho)"

  attributes = {
    region = "southern"
  }

  tags = local.tags

  depends_on = [module.vietnam_thing_group]
}

# Site Thing Groups (Pilot Site)
module "hanoi_site_001_thing_group" {
  source = "../../_module/aws/iot/thing_group"

  thing_group_name  = "Hanoi-Site-001"
  parent_group_name = module.northern_region_thing_group.thing_group_name
  description       = "Hanoi Pilot Site - 15,000 cameras"

  attributes = {
    site_id      = "site-001"
    city         = "Hanoi"
    camera_count = "15000"
    status       = "pilot"
  }

  tags = merge(local.tags, {
    SiteId = "site-001"
    Phase  = "Pilot"
  })

  depends_on = [module.northern_region_thing_group]
}

# Additional site groups for future expansion (commented for Week 1-2)
# Uncomment as needed for Week 9+
/*
module "hanoi_site_002_thing_group" {
  source = "../../_module/aws/iot/thing_group"

  thing_group_name  = "Hanoi-Site-002"
  parent_group_name = module.northern_region_thing_group.thing_group_name
  description       = "Hanoi Site 002"

  attributes = {
    site_id      = "site-002"
    city         = "Hanoi"
    camera_count = "15000"
    status       = "expansion"
  }

  tags = merge(local.tags, {
    SiteId = "site-002"
  })

  depends_on = [module.northern_region_thing_group]
}

module "hcmc_site_001_thing_group" {
  source = "../../_module/aws/iot/thing_group"

  thing_group_name  = "HCMC-Site-001"
  parent_group_name = module.southern_region_thing_group.thing_group_name
  description       = "Ho Chi Minh City Site 001"

  attributes = {
    site_id      = "site-003"
    city         = "HCMC"
    camera_count = "15000"
    status       = "expansion"
  }

  tags = merge(local.tags, {
    SiteId = "site-003"
  })

  depends_on = [module.southern_region_thing_group]
}
*/
