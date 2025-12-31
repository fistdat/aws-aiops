locals {
  product_name = "aismc"
  environment  = "dev"
  country      = "vn"

  key_name = "${local.product_name}-${local.environment}"

  tags = {
    Environment = local.environment
    Product     = local.product_name
    Country     = local.country
    ManagedBy   = "Terraform"
  }
}

