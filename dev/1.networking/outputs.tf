output "vpc" {
  description = "VPC outputs"
  value = {
    vpc_id                = module.vpc.vpc_id
    vpc_cidr_block       = module.vpc.vpc_cidr_block
    vpc_secondary_cidr_block = module.vpc.vpc_secondary_cidr_block

    public_subnet_ids  = module.vpc.public_subnet_ids
    private_subnet_ids = module.vpc.private_subnet_ids
    secondary_private_subnet_ids = module.vpc.secondary_private_subnet_ids
    private_ops_subnet_ids = module.vpc.private_ops_subnet_ids

    public_route_table_id  = module.vpc.public_route_table_id
    private_route_table_ids = module.vpc.private_route_table_ids
    secondary_private_route_table_id = module.vpc.secondary_private_route_table_id
    private_ops_route_table_ids = module.vpc.private_ops_route_table_ids

    internet_gateway_id = module.vpc.internet_gateway_id
    nat_gateway_ids    = module.vpc.nat_gateway_ids
  }
}

