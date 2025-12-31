locals {
  product_name = "aismc"

  tags = {
    Product   = local.product_name
    ManagedBy = "Terraform"
    Project   = "AIOps-IoC"
    Module    = "Organization"
  }
}
