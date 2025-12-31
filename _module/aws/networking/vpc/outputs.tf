output "vpc_id" {
  description = "ID of the VPC"
  value       = aws_vpc.this.id
}

output "vpc_cidr_block" {
  description = "CIDR block of the VPC"
  value       = aws_vpc.this.cidr_block
}

output "public_subnet_ids" {
  description = "List of IDs of public subnets"
  value       = aws_subnet.public[*].id
}

output "private_subnet_ids" {
  description = "List of IDs of private subnets"
  value       = aws_subnet.private[*].id
}

output "public_route_table_id" {
  description = "ID of the public route table"
  value       = aws_route_table.public.id
}

output "private_route_table_ids" {
  description = "List of IDs of private route tables"
  value       = aws_route_table.private[*].id
}

output "internet_gateway_id" {
  description = "ID of the Internet Gateway"
  value       = aws_internet_gateway.this.id
}

output "nat_gateway_ids" {
  description = "List of IDs of NAT Gateways"
  value       = aws_nat_gateway.this[*].id
}

output "vpc_secondary_cidr_block" {
  description = "Secondary CIDR block of the VPC"
  value       = var.secondary_cidr_block != null ? try(aws_vpc_ipv4_cidr_block_association.secondary[0].cidr_block, null) : null
}

output "secondary_private_subnet_ids" {
  description = "List of IDs of secondary private subnets"
  value       = aws_subnet.secondary_private[*].id
}

output "secondary_private_route_table_id" {
  description = "ID of the secondary private route table"
  value       = length(aws_route_table.secondary_private) > 0 ? aws_route_table.secondary_private[0].id : null
}

output "private_ops_subnet_ids" {
  description = "List of IDs of private ops subnets"
  value       = aws_subnet.private_ops[*].id
}

output "private_ops_route_table_ids" {
  description = "List of IDs of private ops route tables"
  value       = aws_route_table.private_ops[*].id
}
