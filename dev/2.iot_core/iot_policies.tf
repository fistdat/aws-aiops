# ============================================================================
# IoT Policies
# ============================================================================

# Policy for Greengrass Core devices
module "greengrass_core_policy" {
  source = "../../_module/aws/iot/iot_policy"

  policy_name = "${local.product_name}-${local.environment}-greengrass-core-policy"

  policy_document = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Action = [
          "iot:Connect"
        ]
        Resource = [
          "arn:aws:iot:${local.region}:${data.aws_caller_identity.current.account_id}:client/SmartHUB-*"
        ]
      },
      {
        Effect = "Allow"
        Action = [
          "iot:Publish",
          "iot:Receive"
        ]
        Resource = [
          "arn:aws:iot:${local.region}:${data.aws_caller_identity.current.account_id}:topic/cameras/*/incidents",
          "arn:aws:iot:${local.region}:${data.aws_caller_identity.current.account_id}:topic/cameras/*/registry",
          "arn:aws:iot:${local.region}:${data.aws_caller_identity.current.account_id}:topic/cameras/*/metrics",
          "arn:aws:iot:${local.region}:${data.aws_caller_identity.current.account_id}:topic/$aws/things/SmartHUB-*/shadow/*"
        ]
      },
      {
        Effect = "Allow"
        Action = [
          "iot:Subscribe"
        ]
        Resource = [
          "arn:aws:iot:${local.region}:${data.aws_caller_identity.current.account_id}:topicfilter/cameras/*/incidents",
          "arn:aws:iot:${local.region}:${data.aws_caller_identity.current.account_id}:topicfilter/$aws/things/SmartHUB-*/shadow/*"
        ]
      },
      {
        Effect = "Allow"
        Action = [
          "iot:UpdateThingShadow",
          "iot:GetThingShadow",
          "iot:DeleteThingShadow"
        ]
        Resource = [
          "arn:aws:iot:${local.region}:${data.aws_caller_identity.current.account_id}:thing/SmartHUB-*"
        ]
      },
      {
        Effect = "Allow"
        Action = [
          "greengrass:*"
        ]
        Resource = "*"
      }
    ]
  })

  tags = local.tags
}

# Restrictive policy for read-only access (future use - dashboard, monitoring)
module "iot_readonly_policy" {
  source = "../../_module/aws/iot/iot_policy"

  policy_name = "${local.product_name}-${local.environment}-iot-readonly-policy"

  policy_document = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Action = [
          "iot:Connect"
        ]
        Resource = "arn:aws:iot:${local.region}:${data.aws_caller_identity.current.account_id}:client/$${iot:Connection.Thing.ThingName}"
      },
      {
        Effect = "Allow"
        Action = [
          "iot:Subscribe"
        ]
        Resource = [
          "arn:aws:iot:${local.region}:${data.aws_caller_identity.current.account_id}:topicfilter/cameras/*/incidents",
          "arn:aws:iot:${local.region}:${data.aws_caller_identity.current.account_id}:topicfilter/cameras/*/metrics"
        ]
      },
      {
        Effect = "Allow"
        Action = [
          "iot:Receive"
        ]
        Resource = [
          "arn:aws:iot:${local.region}:${data.aws_caller_identity.current.account_id}:topic/cameras/*/incidents",
          "arn:aws:iot:${local.region}:${data.aws_caller_identity.current.account_id}:topic/cameras/*/metrics"
        ]
      },
      {
        Effect = "Allow"
        Action = [
          "iot:GetThingShadow"
        ]
        Resource = [
          "arn:aws:iot:${local.region}:${data.aws_caller_identity.current.account_id}:thing/SmartHUB-*"
        ]
      }
    ]
  })

  tags = local.tags
}
