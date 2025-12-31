terraform {
  required_version = ">= 1.5.0"

  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
    }
    archive = {
      source  = "hashicorp/archive"
      version = "~> 2.0"
    }
  }

  # Uncomment after first apply to enable remote state
  # backend "s3" {
  #   bucket         = "aismc-nonprod-terraform-state"
  #   key            = "dev/api-gateway/terraform.tfstate"
  #   region         = "ap-southeast-1"
  #   encrypt        = true
  #   dynamodb_table = "terraform-state-lock"
  # }
}

# ============================================================================
# API Gateway CloudWatch Logging IAM Role
# ============================================================================

resource "aws_iam_role" "api_gateway_cloudwatch" {
  name = "${local.product_name}-${local.environment}-apigateway-cloudwatch-role"

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

  tags = local.tags
}

resource "aws_iam_role_policy_attachment" "api_gateway_cloudwatch" {
  role       = aws_iam_role.api_gateway_cloudwatch.name
  policy_arn = "arn:aws:iam::aws:policy/service-role/AmazonAPIGatewayPushToCloudWatchLogs"
}

resource "aws_api_gateway_account" "main" {
  cloudwatch_role_arn = aws_iam_role.api_gateway_cloudwatch.arn
}

# ============================================================================
# REST API Gateway
# ============================================================================

resource "aws_api_gateway_rest_api" "aiops_api" {
  name        = "${local.product_name}-${local.environment}-aiops-api"
  description = "AIOps IoC REST API"

  endpoint_configuration {
    types = ["REGIONAL"]
  }

  tags = local.tags
}

# ============================================================================
# API Resources
# ============================================================================

# /cameras resource
resource "aws_api_gateway_resource" "cameras" {
  rest_api_id = aws_api_gateway_rest_api.aiops_api.id
  parent_id   = aws_api_gateway_rest_api.aiops_api.root_resource_id
  path_part   = "cameras"
}

# /incidents resource
resource "aws_api_gateway_resource" "incidents" {
  rest_api_id = aws_api_gateway_rest_api.aiops_api.id
  parent_id   = aws_api_gateway_rest_api.aiops_api.root_resource_id
  path_part   = "incidents"
}

# /metrics resource (for future use)
resource "aws_api_gateway_resource" "metrics" {
  rest_api_id = aws_api_gateway_rest_api.aiops_api.id
  parent_id   = aws_api_gateway_rest_api.aiops_api.root_resource_id
  path_part   = "metrics"
}

# ============================================================================
# API Methods - GET /cameras
# ============================================================================

resource "aws_api_gateway_method" "get_cameras" {
  rest_api_id   = aws_api_gateway_rest_api.aiops_api.id
  resource_id   = aws_api_gateway_resource.cameras.id
  http_method   = "GET"
  authorization = "NONE" # TODO: Add authorization later
}

resource "aws_api_gateway_integration" "get_cameras_lambda" {
  rest_api_id             = aws_api_gateway_rest_api.aiops_api.id
  resource_id             = aws_api_gateway_resource.cameras.id
  http_method             = aws_api_gateway_method.get_cameras.http_method
  integration_http_method = "POST"
  type                    = "AWS_PROXY"
  uri                     = aws_lambda_function.get_cameras.invoke_arn
}

# ============================================================================
# API Methods - GET /incidents
# ============================================================================

resource "aws_api_gateway_method" "get_incidents" {
  rest_api_id   = aws_api_gateway_rest_api.aiops_api.id
  resource_id   = aws_api_gateway_resource.incidents.id
  http_method   = "GET"
  authorization = "NONE" # TODO: Add authorization later
}

resource "aws_api_gateway_integration" "get_incidents_lambda" {
  rest_api_id             = aws_api_gateway_rest_api.aiops_api.id
  resource_id             = aws_api_gateway_resource.incidents.id
  http_method             = aws_api_gateway_method.get_incidents.http_method
  integration_http_method = "POST"
  type                    = "AWS_PROXY"
  uri                     = aws_lambda_function.get_incidents.invoke_arn
}

# ============================================================================
# CORS Configuration - OPTIONS method for /cameras
# ============================================================================

resource "aws_api_gateway_method" "cameras_options" {
  rest_api_id   = aws_api_gateway_rest_api.aiops_api.id
  resource_id   = aws_api_gateway_resource.cameras.id
  http_method   = "OPTIONS"
  authorization = "NONE"
}

resource "aws_api_gateway_integration" "cameras_options" {
  rest_api_id = aws_api_gateway_rest_api.aiops_api.id
  resource_id = aws_api_gateway_resource.cameras.id
  http_method = aws_api_gateway_method.cameras_options.http_method
  type        = "MOCK"

  request_templates = {
    "application/json" = "{\"statusCode\": 200}"
  }
}

resource "aws_api_gateway_method_response" "cameras_options_200" {
  rest_api_id = aws_api_gateway_rest_api.aiops_api.id
  resource_id = aws_api_gateway_resource.cameras.id
  http_method = aws_api_gateway_method.cameras_options.http_method
  status_code = "200"

  response_parameters = {
    "method.response.header.Access-Control-Allow-Headers" = true
    "method.response.header.Access-Control-Allow-Methods" = true
    "method.response.header.Access-Control-Allow-Origin"  = true
  }
}

resource "aws_api_gateway_integration_response" "cameras_options_200" {
  rest_api_id = aws_api_gateway_rest_api.aiops_api.id
  resource_id = aws_api_gateway_resource.cameras.id
  http_method = aws_api_gateway_method.cameras_options.http_method
  status_code = aws_api_gateway_method_response.cameras_options_200.status_code

  response_parameters = {
    "method.response.header.Access-Control-Allow-Headers" = "'Content-Type,X-Amz-Date,Authorization,X-Api-Key,X-Amz-Security-Token'"
    "method.response.header.Access-Control-Allow-Methods" = "'GET,OPTIONS'"
    "method.response.header.Access-Control-Allow-Origin"  = "'*'"
  }

  depends_on = [aws_api_gateway_integration.cameras_options]
}

# ============================================================================
# API Deployment
# ============================================================================

resource "aws_api_gateway_deployment" "api_deployment" {
  rest_api_id = aws_api_gateway_rest_api.aiops_api.id

  depends_on = [
    aws_api_gateway_integration.get_cameras_lambda,
    aws_api_gateway_integration.get_incidents_lambda,
    aws_api_gateway_integration.cameras_options
  ]

  lifecycle {
    create_before_destroy = true
  }

  triggers = {
    # Redeploy when any integration changes
    redeployment = sha1(jsonencode([
      aws_api_gateway_integration.get_cameras_lambda,
      aws_api_gateway_integration.get_incidents_lambda,
    ]))
  }
}

# ============================================================================
# API Stage
# ============================================================================

resource "aws_api_gateway_stage" "dev" {
  deployment_id = aws_api_gateway_deployment.api_deployment.id
  rest_api_id   = aws_api_gateway_rest_api.aiops_api.id
  stage_name    = "dev"

  tags = local.tags
}

# Enable API Gateway logging
resource "aws_api_gateway_method_settings" "all" {
  rest_api_id = aws_api_gateway_rest_api.aiops_api.id
  stage_name  = aws_api_gateway_stage.dev.stage_name
  method_path = "*/*"

  settings {
    metrics_enabled = true
    logging_level   = "INFO"
  }
}

# ============================================================================
# CloudWatch Log Group for API Gateway
# ============================================================================

resource "aws_cloudwatch_log_group" "api_gateway_logs" {
  name              = "/aws/apigateway/${local.product_name}-${local.environment}"
  retention_in_days = 30

  tags = local.tags
}
