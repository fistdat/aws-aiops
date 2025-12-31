# VPC Module (AWS) - Simple

Reusable Terraform module to provision a simple AWS VPC with:
- VPC with DNS support
- Public and private subnets across 2 AZs
- Internet Gateway for public egress
- Optional NAT Gateways (one per AZ)
- Route tables and associations

## Usage

### Basic VPC

```hcl
module "vpc" {
  source = "./_module/aws/networking/vpc"

  name                = "vpc-aismc-dev"
  cidr_block          = "10.0.0.0/16"
  public_subnet_cidrs = ["10.0.1.0/24", "10.0.2.0/24"]
  private_subnet_cidrs = ["10.0.11.0/24", "10.0.12.0/24"]

  create_nat_gateways = true

  tags = {
    Environment = "dev"
    Product     = "aismc"
    ManagedBy   = "Terraform"
  }
}
```

### VPC with Secondary CIDR

```hcl
module "vpc" {
  source = "./_module/aws/networking/vpc"

  name                = "vpc-aismc-dev"
  cidr_block          = "10.0.0.0/16"
  public_subnet_cidrs = ["10.0.1.0/24", "10.0.2.0/24"]
  private_subnet_cidrs = ["10.0.11.0/24", "10.0.12.0/24"]

  secondary_cidr_block          = "100.64.0.0/16"
  secondary_private_subnet_cidrs = ["100.64.1.0/24", "100.64.2.0/24"]

  create_nat_gateways = true

  tags = {
    Environment = "dev"
    Product     = "aismc"
    ManagedBy   = "Terraform"
  }
}
```

## Inputs

| Name | Description | Type | Default | Required |
|------|-------------|------|---------|:--------:|
| name | Name of the VPC | `string` | n/a | yes |
| cidr_block | CIDR block for the VPC | `string` | n/a | yes |
| public_subnet_cidrs | List of CIDR blocks for public subnets (one per AZ) | `list(string)` | n/a | yes |
| private_subnet_cidrs | List of CIDR blocks for private subnets (one per AZ) | `list(string)` | n/a | yes |
| create_nat_gateways | Whether to create NAT Gateways (one per AZ) | `bool` | `true` | no |
| secondary_cidr_block | Secondary CIDR block to attach to VPC (optional) | `string` | `null` | no |
| secondary_private_subnet_cidrs | List of CIDR blocks for secondary private subnets (one per AZ, optional) | `list(string)` | `[]` | no |
| tags | A map of tags to assign to the resource | `map(string)` | `{}` | no |

## Outputs

| Name | Description |
|------|-------------|
| vpc_id | ID of the VPC |
| vpc_cidr_block | CIDR block of the VPC |
| vpc_secondary_cidr_block | Secondary CIDR block of the VPC (if configured) |
| public_subnet_ids | List of IDs of public subnets |
| private_subnet_ids | List of IDs of private subnets |
| secondary_private_subnet_ids | List of IDs of secondary private subnets (if configured) |
| public_route_table_id | ID of the public route table |
| private_route_table_ids | List of IDs of private route tables |
| secondary_private_route_table_id | ID of the secondary private route table (if configured) |
| internet_gateway_id | ID of the Internet Gateway |
| nat_gateway_ids | List of IDs of NAT Gateways |

## Notes

- Availability Zones are hardcoded to use `{region}a` and `{region}b` (e.g., `ap-southeast-1a`, `ap-southeast-1b`)
- Public subnets have `map_public_ip_on_launch = true`
- Private subnets route through NAT Gateways (if created) for internet access
- One NAT Gateway per AZ is created when `create_nat_gateways = true`
- Secondary CIDR block is optional and can be used to expand VPC address space
- Secondary private subnets are created only if both `secondary_cidr_block` and `secondary_private_subnet_cidrs` are provided
- Secondary private route table includes routes for both primary and secondary CIDR blocks
