variable "thing_group_name" {
  description = "Name of the Thing Group"
  type        = string
}

variable "parent_group_name" {
  description = "Parent Thing Group name"
  type        = string
  default     = ""
}

variable "description" {
  type    = string
  default = ""
}

variable "attributes" {
  type    = map(string)
  default = {}
}

variable "tags" {
  type    = map(string)
  default = {}
}
