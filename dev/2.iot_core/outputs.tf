# Thing Groups
output "vietnam_thing_group_arn" {
  description = "ARN of Vietnam root Thing Group"
  value       = module.vietnam_thing_group.thing_group_arn
}

output "northern_region_thing_group_arn" {
  description = "ARN of Northern Region Thing Group"
  value       = module.northern_region_thing_group.thing_group_arn
}

output "central_region_thing_group_arn" {
  description = "ARN of Central Region Thing Group"
  value       = module.central_region_thing_group.thing_group_arn
}

output "southern_region_thing_group_arn" {
  description = "ARN of Southern Region Thing Group"
  value       = module.southern_region_thing_group.thing_group_arn
}

output "hanoi_site_001_thing_group_arn" {
  description = "ARN of Hanoi Site 001 Thing Group"
  value       = module.hanoi_site_001_thing_group.thing_group_arn
}

# IoT Policies
output "greengrass_core_policy_name" {
  description = "Name of Greengrass Core IoT Policy"
  value       = module.greengrass_core_policy.policy_name
}

output "greengrass_core_policy_arn" {
  description = "ARN of Greengrass Core IoT Policy"
  value       = module.greengrass_core_policy.policy_arn
}

output "iot_readonly_policy_name" {
  description = "Name of read-only IoT Policy"
  value       = module.iot_readonly_policy.policy_name
}

output "iot_readonly_policy_arn" {
  description = "ARN of read-only IoT Policy"
  value       = module.iot_readonly_policy.policy_arn
}

# IoT Endpoints
output "iot_data_endpoint" {
  description = "IoT Core Data Endpoint (for MQTT)"
  value       = data.aws_iot_endpoint.data.endpoint_address
}

output "iot_credentials_endpoint" {
  description = "IoT Core Credentials Endpoint"
  value       = data.aws_iot_endpoint.credentials.endpoint_address
}

# Certificate Infrastructure
output "certificate_bucket_name" {
  description = "S3 bucket for certificate metadata"
  value       = aws_s3_bucket.iot_certificates.id
}

output "certificate_bucket_arn" {
  description = "ARN of certificate bucket"
  value       = aws_s3_bucket.iot_certificates.arn
}

output "certificate_registry_table_name" {
  description = "DynamoDB table for certificate tracking"
  value       = aws_dynamodb_table.certificate_registry.name
}

output "certificate_registry_table_arn" {
  description = "ARN of certificate registry table"
  value       = aws_dynamodb_table.certificate_registry.arn
}

# MQTT Topics
output "mqtt_topics" {
  description = "MQTT topic structure"
  value       = local.mqtt_topics
}
