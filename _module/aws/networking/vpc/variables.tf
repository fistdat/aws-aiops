variable "name" {
  description = "Name of the VPC"
  type        = string
}

variable "cidr_block" {
  description = "CIDR block for the VPC"
  type        = string
}

variable "public_subnet_cidrs" {
  description = "List of CIDR blocks for public subnets (one per AZ)"
  type        = list(string)
}

variable "private_subnet_cidrs" {
  description = "List of CIDR blocks for private subnets (one per AZ)"
  type        = list(string)
}

variable "create_nat_gateways" {
  description = "Whether to create NAT Gateways (one per AZ)"
  type        = bool
  default     = true
}

variable "secondary_cidr_block" {
  description = "Secondary CIDR block to attach to VPC (optional)"
  type        = string
  default     = null
}

variable "secondary_private_subnet_cidrs" {
  description = "List of CIDR blocks for secondary private subnets (one per AZ, optional)"
  type        = list(string)
  default     = []
}

variable "private_ops_cidrs" {
  description = "List of CIDR blocks for private ops subnets (one per AZ, /27)"
  type        = list(string)
  default     = []
}

variable "tags" {
  description = "A map of tags to assign to the resource"
  type        = map(string)
  default     = {}
}
