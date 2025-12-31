variable "policy_name" {
  description = "Name of the IoT Policy"
  type        = string
}

variable "policy_document" {
  description = "IoT Policy document in JSON format"
  type        = string
}

variable "tags" {
  description = "Tags for the IoT Policy"
  type        = map(string)
  default     = {}
}
