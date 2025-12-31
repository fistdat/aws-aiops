resource "aws_iot_policy" "this" {
  name   = var.policy_name
  policy = var.policy_document

  tags = var.tags
}
