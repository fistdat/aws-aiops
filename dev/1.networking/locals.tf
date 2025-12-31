locals {
  product_name = "aismc"
  environment  = "dev"

  tags = {
    Environment = local.environment
    Product     = local.product_name
    ManagedBy   = "Terraform"
  }

  # Main CIDR - 10.246.136.0/22 (1024 IPs: 10.246.136.0 - 10.246.139.255)
  vpc_cidr = "10.246.136.0/22"

  # Secondary CIDR (optional)
  secondary_cidr_block            = "100.64.0.0/20"
  secondary_private_subnet_cidrs = ["100.64.0.0/21", "100.64.8.0/21"]

  # Public subnets - /27 each (32 IPs)
  public_subnet_cidrs = ["10.246.136.0/27", "10.246.136.32/27"]

  # Private subnets - /27 each (32 IPs)
  private_subnet_cidrs = ["10.246.136.64/27", "10.246.136.96/27"]

  # Private Ops subnets - /27 each (32 IPs)
  private_ops_cidrs = ["10.246.136.128/27", "10.246.136.160/27"]
}

