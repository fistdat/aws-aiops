resource "aws_iot_thing_group" "this" {
  name              = var.thing_group_name
  parent_group_name = var.parent_group_name != "" ? var.parent_group_name : null

  properties {
    description = var.description
    attribute_payload {
      attributes = var.attributes
    }
  }

  tags = var.tags
}
