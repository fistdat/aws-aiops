# ============================================================================
# Data Sources
# ============================================================================

data "terraform_remote_state" "data_layer" {
  backend = "s3"
  config = {
    bucket = "aismc-platform-terraformstatefile-20251101-061100493617"
    key    = "aismc-dev/3.data_layer/terraform.tfstate"
    region = "ap-southeast-1"
  }
}

data "terraform_remote_state" "iam" {
  backend = "s3"
  config = {
    bucket = "aismc-platform-terraformstatefile-20251101-061100493617"
    key    = "aismc-dev/0.iam_assume_role_terraform/terraform.tfstate"
    region = "ap-southeast-1"
  }
}

data "aws_region" "current" {}

# ============================================================================
# Lambda Deployment Packages
# ============================================================================

# Package get_cameras Lambda
data "archive_file" "get_cameras" {
  type        = "zip"
  source_dir  = "${path.module}/lambda/get_cameras"
  output_path = "${path.module}/lambda/get_cameras.zip"
}

# Package get_incidents Lambda
data "archive_file" "get_incidents" {
  type        = "zip"
  source_dir  = "${path.module}/lambda/get_incidents"
  output_path = "${path.module}/lambda/get_incidents.zip"
}

# ============================================================================
# Lambda Functions
# ============================================================================

# Lambda function: GET /cameras
resource "aws_lambda_function" "get_cameras" {
  filename         = data.archive_file.get_cameras.output_path
  function_name    = "${local.product_name}-${local.environment}-get-cameras"
  role             = data.terraform_remote_state.iam.outputs.iot_lambda_role_arn
  handler          = "index.handler"
  runtime          = "python3.11"
  timeout          = 30
  memory_size      = 256
  source_code_hash = data.archive_file.get_cameras.output_base64sha256

  environment {
    variables = {
      DEVICE_REGISTRY_TABLE = data.terraform_remote_state.data_layer.outputs.device_registry_table_name
      REGION                = data.aws_region.current.name
    }
  }

  tags = merge(local.tags, {
    Function = "Query Camera Registry"
  })
}

# Lambda CloudWatch Log Group
resource "aws_cloudwatch_log_group" "lambda_get_cameras_logs" {
  name              = "/aws/lambda/${aws_lambda_function.get_cameras.function_name}"
  retention_in_days = 30

  tags = local.tags
}

# Lambda permission for API Gateway to invoke get_cameras
resource "aws_lambda_permission" "apigw_get_cameras" {
  statement_id  = "AllowAPIGatewayInvoke"
  action        = "lambda:InvokeFunction"
  function_name = aws_lambda_function.get_cameras.function_name
  principal     = "apigateway.amazonaws.com"
  source_arn    = "${aws_api_gateway_rest_api.aiops_api.execution_arn}/*/*"
}

# Lambda function: GET /incidents
resource "aws_lambda_function" "get_incidents" {
  filename         = data.archive_file.get_incidents.output_path
  function_name    = "${local.product_name}-${local.environment}-get-incidents"
  role             = data.terraform_remote_state.iam.outputs.iot_lambda_role_arn
  handler          = "index.handler"
  runtime          = "python3.11"
  timeout          = 30
  memory_size      = 256
  source_code_hash = data.archive_file.get_incidents.output_base64sha256

  environment {
    variables = {
      INCIDENTS_TABLE = data.terraform_remote_state.data_layer.outputs.camera_incidents_table_name
      REGION          = data.aws_region.current.name
    }
  }

  tags = merge(local.tags, {
    Function = "Query Camera Incidents"
  })
}

# Lambda CloudWatch Log Group
resource "aws_cloudwatch_log_group" "lambda_get_incidents_logs" {
  name              = "/aws/lambda/${aws_lambda_function.get_incidents.function_name}"
  retention_in_days = 30

  tags = local.tags
}

# Lambda permission for API Gateway to invoke get_incidents
resource "aws_lambda_permission" "apigw_get_incidents" {
  statement_id  = "AllowAPIGatewayInvoke"
  action        = "lambda:InvokeFunction"
  function_name = aws_lambda_function.get_incidents.function_name
  principal     = "apigateway.amazonaws.com"
  source_arn    = "${aws_api_gateway_rest_api.aiops_api.execution_arn}/*/*"
}
