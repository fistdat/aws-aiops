# Data source for current account
data "aws_caller_identity" "current" {}

data "aws_region" "current" {}

locals {
  product_name = "aismc"
  environment  = "dev"
  region       = data.aws_region.current.name
  account_id   = data.aws_caller_identity.current.account_id

  common_tags = {
    Environment = local.environment
    Product     = local.product_name
    ManagedBy   = "Terraform"
    Project     = "AIOps-IoC"
  }
}

# ============================================================================
# IoT Core Service Role
# ============================================================================
resource "aws_iam_role" "iot_core_service_role" {
  name = "${local.product_name}-${local.environment}-iot-core-service-role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Action = "sts:AssumeRole"
      Effect = "Allow"
      Principal = {
        Service = "iot.amazonaws.com"
      }
    }]
  })

  tags = merge(local.common_tags, {
    Role = "IoT Core Service"
  })
}

# Policy for IoT Core to write to DynamoDB
resource "aws_iam_role_policy" "iot_dynamodb_policy" {
  name = "iot-dynamodb-access"
  role = aws_iam_role.iot_core_service_role.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Action = [
          "dynamodb:PutItem",
          "dynamodb:UpdateItem",
          "dynamodb:BatchWriteItem"
        ]
        Resource = [
          "arn:aws:dynamodb:${local.region}:${local.account_id}:table/${local.product_name}-${local.environment}-*"
        ]
      }
    ]
  })
}

# Policy for IoT Core to write to Timestream
resource "aws_iam_role_policy" "iot_timestream_policy" {
  name = "iot-timestream-access"
  role = aws_iam_role.iot_core_service_role.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Action = [
          "timestream:WriteRecords",
          "timestream:DescribeEndpoints"
        ]
        Resource = [
          "arn:aws:timestream:${local.region}:${local.account_id}:database/${local.product_name}-${local.environment}-*/*"
        ]
      }
    ]
  })
}

# Policy for IoT Core to publish to SNS
resource "aws_iam_role_policy" "iot_sns_policy" {
  name = "iot-sns-access"
  role = aws_iam_role.iot_core_service_role.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Action = [
          "sns:Publish"
        ]
        Resource = [
          "arn:aws:sns:${local.region}:${local.account_id}:${local.product_name}-${local.environment}-*"
        ]
      }
    ]
  })
}

# Policy for IoT Core to write to CloudWatch Logs
resource "aws_iam_role_policy" "iot_cloudwatch_policy" {
  name = "iot-cloudwatch-access"
  role = aws_iam_role.iot_core_service_role.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Action = [
          "logs:CreateLogGroup",
          "logs:CreateLogStream",
          "logs:PutLogEvents",
          "logs:DescribeLogStreams"
        ]
        Resource = [
          "arn:aws:logs:${local.region}:${local.account_id}:log-group:/aws/iot/*"
        ]
      }
    ]
  })
}

# ============================================================================
# Greengrass Core Device Role
# ============================================================================
resource "aws_iam_role" "greengrass_core_role" {
  name = "${local.product_name}-${local.environment}-greengrass-core-role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Action = "sts:AssumeRole"
      Effect = "Allow"
      Principal = {
        Service = "credentials.iot.amazonaws.com"
      }
    }]
  })

  tags = merge(local.common_tags, {
    Role = "Greengrass Core Device"
  })
}

# Attach AWS managed policy for Greengrass
resource "aws_iam_role_policy_attachment" "greengrass_core_policy" {
  role       = aws_iam_role.greengrass_core_role.name
  policy_arn = "arn:aws:iam::aws:policy/service-role/AWSGreengrassResourceAccessRolePolicy"
}

# Additional policy for Greengrass to access S3 (for component artifacts)
resource "aws_iam_role_policy" "greengrass_s3_policy" {
  name = "greengrass-s3-access"
  role = aws_iam_role.greengrass_core_role.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Action = [
          "s3:GetObject"
        ]
        Resource = [
          "arn:aws:s3:::${local.product_name}-${local.environment}-*/*"
        ]
      }
    ]
  })
}

# Policy for Greengrass to publish to IoT Core
resource "aws_iam_role_policy" "greengrass_iot_policy" {
  name = "greengrass-iot-access"
  role = aws_iam_role.greengrass_core_role.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Action = [
          "iot:Publish",
          "iot:Subscribe",
          "iot:Connect",
          "iot:Receive"
        ]
        Resource = "*"
      },
      {
        Effect = "Allow"
        Action = [
          "iot:GetThingShadow",
          "iot:UpdateThingShadow",
          "iot:DeleteThingShadow"
        ]
        Resource = [
          "arn:aws:iot:${local.region}:${local.account_id}:thing/SmartHUB-*"
        ]
      }
    ]
  })
}

# ============================================================================
# Lambda Execution Role for IoT Rules
# ============================================================================
resource "aws_iam_role" "iot_lambda_role" {
  name = "${local.product_name}-${local.environment}-iot-lambda-role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Action = "sts:AssumeRole"
      Effect = "Allow"
      Principal = {
        Service = "lambda.amazonaws.com"
      }
    }]
  })

  tags = merge(local.common_tags, {
    Role = "Lambda Execution for IoT"
  })
}

# Attach AWS managed policy for Lambda basic execution
resource "aws_iam_role_policy_attachment" "lambda_basic" {
  role       = aws_iam_role.iot_lambda_role.name
  policy_arn = "arn:aws:iam::aws:policy/service-role/AWSLambdaBasicExecutionRole"
}

# Policy for Lambda to access DynamoDB
resource "aws_iam_role_policy" "lambda_dynamodb_access" {
  name = "lambda-dynamodb-access"
  role = aws_iam_role.iot_lambda_role.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Effect = "Allow"
      Action = [
        "dynamodb:PutItem",
        "dynamodb:GetItem",
        "dynamodb:UpdateItem",
        "dynamodb:DeleteItem",
        "dynamodb:Query",
        "dynamodb:Scan",
        "dynamodb:BatchGetItem",
        "dynamodb:BatchWriteItem"
      ]
      Resource = [
        "arn:aws:dynamodb:${local.region}:${local.account_id}:table/${local.product_name}-${local.environment}-*",
        "arn:aws:dynamodb:${local.region}:${local.account_id}:table/${local.product_name}-${local.environment}-*/index/*"
      ]
    }]
  })
}

# Policy for Lambda to access Timestream
resource "aws_iam_role_policy" "lambda_timestream_access" {
  name = "lambda-timestream-access"
  role = aws_iam_role.iot_lambda_role.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Effect = "Allow"
      Action = [
        "timestream:Select",
        "timestream:DescribeEndpoints"
      ]
      Resource = [
        "arn:aws:timestream:${local.region}:${local.account_id}:database/${local.product_name}-${local.environment}-*/*"
      ]
    }]
  })
}

# ============================================================================
# API Gateway Execution Role (if needed)
# ============================================================================
resource "aws_iam_role" "api_gateway_role" {
  name = "${local.product_name}-${local.environment}-api-gateway-role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Action = "sts:AssumeRole"
      Effect = "Allow"
      Principal = {
        Service = "apigateway.amazonaws.com"
      }
    }]
  })

  tags = merge(local.common_tags, {
    Role = "API Gateway Execution"
  })
}

# Policy for API Gateway to write CloudWatch Logs
resource "aws_iam_role_policy" "api_gateway_cloudwatch" {
  name = "api-gateway-cloudwatch-access"
  role = aws_iam_role.api_gateway_role.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Effect = "Allow"
      Action = [
        "logs:CreateLogGroup",
        "logs:CreateLogStream",
        "logs:DescribeLogGroups",
        "logs:DescribeLogStreams",
        "logs:PutLogEvents",
        "logs:GetLogEvents",
        "logs:FilterLogEvents"
      ]
      Resource = "*"
    }]
  })
}

# ============================================================================
# Outputs
# ============================================================================
output "iot_core_service_role_arn" {
  description = "ARN of the IoT Core service role"
  value       = aws_iam_role.iot_core_service_role.arn
}

output "greengrass_core_role_arn" {
  description = "ARN of the Greengrass Core role"
  value       = aws_iam_role.greengrass_core_role.arn
}

output "iot_lambda_role_arn" {
  description = "ARN of the Lambda execution role for IoT"
  value       = aws_iam_role.iot_lambda_role.arn
}

output "api_gateway_role_arn" {
  description = "ARN of the API Gateway execution role"
  value       = aws_iam_role.api_gateway_role.arn
}
