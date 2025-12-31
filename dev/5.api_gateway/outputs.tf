# API Gateway
output "api_gateway_id" {
  description = "API Gateway REST API ID"
  value       = aws_api_gateway_rest_api.aiops_api.id
}

output "api_gateway_endpoint" {
  description = "API Gateway endpoint URL"
  value       = "${aws_api_gateway_stage.dev.invoke_url}"
}

output "api_gateway_stage" {
  description = "API Gateway stage name"
  value       = aws_api_gateway_stage.dev.stage_name
}

output "api_gateway_arn" {
  description = "API Gateway ARN"
  value       = aws_api_gateway_rest_api.aiops_api.arn
}

# Lambda Functions
output "lambda_functions" {
  description = "Lambda function ARNs"
  value = {
    get_cameras   = aws_lambda_function.get_cameras.arn
    get_incidents = aws_lambda_function.get_incidents.arn
  }
}

output "get_cameras_function_name" {
  description = "Name of get_cameras Lambda function"
  value       = aws_lambda_function.get_cameras.function_name
}

output "get_incidents_function_name" {
  description = "Name of get_incidents Lambda function"
  value       = aws_lambda_function.get_incidents.function_name
}

# API Endpoints
output "cameras_endpoint" {
  description = "Full endpoint URL for /cameras"
  value       = "${aws_api_gateway_stage.dev.invoke_url}/cameras"
}

output "incidents_endpoint" {
  description = "Full endpoint URL for /incidents"
  value       = "${aws_api_gateway_stage.dev.invoke_url}/incidents"
}
