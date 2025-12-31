variable "table_name" {
  description = "DynamoDB table name"
  type        = string
}

variable "billing_mode" {
  description = "DynamoDB billing mode (PROVISIONED or PAY_PER_REQUEST)"
  type        = string
  default     = "PAY_PER_REQUEST"
}

variable "hash_key" {
  description = "Hash key (partition key) attribute name"
  type        = string
}

variable "range_key" {
  description = "Range key (sort key) attribute name (optional)"
  type        = string
  default     = ""
}

variable "attributes" {
  description = "List of attribute definitions (name and type)"
  type = list(object({
    name = string
    type = string # S, N, or B
  }))
}

variable "global_secondary_indexes" {
  description = "List of global secondary indexes"
  type = list(object({
    name            = string
    hash_key        = string
    range_key       = string
    projection_type = string # ALL, KEYS_ONLY, or INCLUDE
  }))
  default = []
}

variable "ttl_attribute_name" {
  description = "Time to Live attribute name (optional)"
  type        = string
  default     = ""
}

variable "point_in_time_recovery" {
  description = "Enable point-in-time recovery backups"
  type        = bool
  default     = true
}

variable "tags" {
  description = "Tags to apply to the table"
  type        = map(string)
  default     = {}
}
