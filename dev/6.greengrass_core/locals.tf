locals {
  product_name = "aismc"
  environment  = "dev"
  region       = data.aws_region.current.name
  account_id   = data.aws_caller_identity.current.account_id

  tags = {
    Environment = local.environment
    Product     = local.product_name
    ManagedBy   = "Terraform"
    Project     = "AIOps-IoC"
    Layer       = "Greengrass-Core"
  }
}

data "aws_region" "current" {}
data "aws_caller_identity" "current" {}
