data "aws_region" "current" {}

locals {
  availability_zones = ["${data.aws_region.current.id}a", "${data.aws_region.current.id}b"]
}

# VPC
resource "aws_vpc" "this" {
  cidr_block           = var.cidr_block
  enable_dns_hostnames = true
  enable_dns_support   = true

  tags = merge(
    var.tags,
    {
      Name = var.name
    }
  )
}

# Attach secondary CIDR block to VPC (optional)
resource "aws_vpc_ipv4_cidr_block_association" "secondary" {
  count = var.secondary_cidr_block != null ? 1 : 0

  vpc_id     = aws_vpc.this.id
  cidr_block = var.secondary_cidr_block
}

# Public Subnets
resource "aws_subnet" "public" {
  count = length(var.public_subnet_cidrs)

  vpc_id                  = aws_vpc.this.id
  cidr_block              = var.public_subnet_cidrs[count.index]
  availability_zone       = local.availability_zones[count.index]
  map_public_ip_on_launch = true

  tags = merge(
    var.tags,
    {
      Name = "${var.name}-public-${local.availability_zones[count.index]}"
      Type = "public"
    }
  )
}

# Private Subnets
resource "aws_subnet" "private" {
  count = length(var.private_subnet_cidrs)

  vpc_id            = aws_vpc.this.id
  cidr_block        = var.private_subnet_cidrs[count.index]
  availability_zone = local.availability_zones[count.index]

  tags = merge(
    var.tags,
    {
      Name = "${var.name}-private-${local.availability_zones[count.index]}"
      Type = "private"
    }
  )
}

# Internet Gateway
resource "aws_internet_gateway" "this" {
  vpc_id = aws_vpc.this.id

  tags = merge(
    var.tags,
    {
      Name = "${var.name}-igw"
    }
  )
}

# Public Route Table
resource "aws_route_table" "public" {
  vpc_id = aws_vpc.this.id

  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = aws_internet_gateway.this.id
  }

  tags = merge(
    var.tags,
    {
      Name = "${var.name}-public-rt"
    }
  )
}

# Public Route Table Associations
resource "aws_route_table_association" "public" {
  count = length(aws_subnet.public)

  subnet_id      = aws_subnet.public[count.index].id
  route_table_id = aws_route_table.public.id
}

# Private Route Tables (one per AZ)
resource "aws_route_table" "private" {
  count = length(var.private_subnet_cidrs)

  vpc_id = aws_vpc.this.id

  tags = merge(
    var.tags,
    {
      Name = "${var.name}-private-rt-${local.availability_zones[count.index]}"
    }
  )
}

# Private Route Table Associations
resource "aws_route_table_association" "private" {
  count = length(aws_subnet.private)

  subnet_id      = aws_subnet.private[count.index].id
  route_table_id = aws_route_table.private[count.index].id
}

# NAT Gateway (optional)
resource "aws_eip" "nat" {
  count = var.create_nat_gateways ? length(var.public_subnet_cidrs) : 0

  domain = "vpc"

  tags = merge(
    var.tags,
    {
      Name = "${var.name}-nat-eip-${local.availability_zones[count.index]}"
    }
  )

  depends_on = [aws_internet_gateway.this]
}

resource "aws_nat_gateway" "this" {
  count = var.create_nat_gateways ? length(var.public_subnet_cidrs) : 0

  allocation_id = aws_eip.nat[count.index].id
  subnet_id     = aws_subnet.public[count.index].id

  tags = merge(
    var.tags,
    {
      Name = "${var.name}-nat-${local.availability_zones[count.index]}"
    }
  )

  depends_on = [aws_internet_gateway.this]
}

# Add NAT Gateway routes to private route tables
resource "aws_route" "private_nat" {
  count = var.create_nat_gateways ? length(aws_route_table.private) : 0

  route_table_id         = aws_route_table.private[count.index].id
  destination_cidr_block = "0.0.0.0/0"
  nat_gateway_id         = aws_nat_gateway.this[count.index].id
}

# Secondary Private Subnets (from secondary CIDR block)
resource "aws_subnet" "secondary_private" {
  count = var.secondary_cidr_block != null && length(var.secondary_private_subnet_cidrs) > 0 ? length(var.secondary_private_subnet_cidrs) : 0

  vpc_id            = aws_vpc.this.id
  cidr_block        = var.secondary_private_subnet_cidrs[count.index]
  availability_zone = local.availability_zones[count.index]

  depends_on = [aws_vpc_ipv4_cidr_block_association.secondary]

  tags = merge(
    var.tags,
    {
      Name = "${var.name}-secondary-private-${local.availability_zones[count.index]}"
      Type = "secondary-private"
    }
  )
}

# Secondary Private Route Table
resource "aws_route_table" "secondary_private" {
  count = var.secondary_cidr_block != null && length(var.secondary_private_subnet_cidrs) > 0 ? 1 : 0

  vpc_id = aws_vpc.this.id

  # Route for secondary CIDR block to local
  route {
    cidr_block = var.secondary_cidr_block
    gateway_id = "local"
  }

  # Route for primary VPC CIDR block to local
  route {
    cidr_block = var.cidr_block
    gateway_id = "local"
  }

  tags = merge(
    var.tags,
    {
      Name = "${var.name}-secondary-private-rt"
    }
  )
}

# Secondary Private Route Table Associations
resource "aws_route_table_association" "secondary_private" {
  count = length(aws_subnet.secondary_private)

  subnet_id      = aws_subnet.secondary_private[count.index].id
  route_table_id = aws_route_table.secondary_private[0].id
}

# Private Ops Subnets
resource "aws_subnet" "private_ops" {
  count = length(var.private_ops_cidrs)

  vpc_id            = aws_vpc.this.id
  cidr_block        = var.private_ops_cidrs[count.index]
  availability_zone = local.availability_zones[count.index]

  tags = merge(
    var.tags,
    {
      Name = "${var.name}-private-ops-${local.availability_zones[count.index]}"
      Type = "private-ops"
    }
  )
}

# Private Ops Route Tables (one per AZ)
resource "aws_route_table" "private_ops" {
  count = length(var.private_ops_cidrs)

  vpc_id = aws_vpc.this.id

  tags = merge(
    var.tags,
    {
      Name = "${var.name}-private-ops-rt-${local.availability_zones[count.index]}"
    }
  )
}

# Private Ops Route Table Associations
resource "aws_route_table_association" "private_ops" {
  count = length(aws_subnet.private_ops)

  subnet_id      = aws_subnet.private_ops[count.index].id
  route_table_id = aws_route_table.private_ops[count.index].id
}
