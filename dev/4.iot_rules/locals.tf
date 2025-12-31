locals {
  product_name = "aismc"
  environment  = "dev"

  tags = {
    Environment = local.environment
    Product     = local.product_name
    ManagedBy   = "Terraform"
    Project     = "AIOps-IoC"
    Layer       = "Integration"
  }
}
