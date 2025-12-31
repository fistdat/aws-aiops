# ============================================================================
# Variables for Greengrass Thing Module
# ============================================================================

variable "thing_name" {
  description = "Name of the IoT Thing for Greengrass Core"
  type        = string

  validation {
    condition     = can(regex("^[a-zA-Z0-9:_-]+$", var.thing_name))
    error_message = "Thing name must contain only alphanumeric characters, colons, underscores, and hyphens."
  }
}

variable "attributes" {
  description = "Attributes for the IoT Thing"
  type        = map(string)
  default     = {}
}

variable "policy_name" {
  description = "Name of the IoT Policy to attach to the certificate"
  type        = string
}

variable "thing_group_name" {
  description = "Name of the Thing Group to add this thing to"
  type        = string
}

variable "tags" {
  description = "Tags to apply to all resources"
  type        = map(string)
  default     = {}
}

variable "save_credentials_locally" {
  description = "Whether to save credentials to local files (for initial setup)"
  type        = bool
  default     = true
}

variable "credentials_output_path" {
  description = "Local path to save certificate and keys"
  type        = string
  default     = "./greengrass-credentials"
}
