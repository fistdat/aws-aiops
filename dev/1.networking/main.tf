module "vpc" {
  source = "../../_module/aws/networking/vpc"

  name                = "${local.product_name}-${local.environment}"
  cidr_block          = local.vpc_cidr
  public_subnet_cidrs = local.public_subnet_cidrs
  private_subnet_cidrs = local.private_subnet_cidrs

  # Secondary CIDR (optional)
  secondary_cidr_block          = local.secondary_cidr_block
  secondary_private_subnet_cidrs = local.secondary_private_subnet_cidrs

  # Private Ops subnets
  private_ops_cidrs = local.private_ops_cidrs

  # NAT Gateways
  create_nat_gateways = true

  tags = local.tags
}

