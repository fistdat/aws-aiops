# DynamoDB Tables
output "device_registry_table_name" {
  description = "Device Registry DynamoDB table name"
  value       = module.device_registry_table.table_name
}

output "device_registry_table_arn" {
  description = "Device Registry DynamoDB table ARN"
  value       = module.device_registry_table.table_arn
}

output "camera_incidents_table_name" {
  description = "Camera Incidents DynamoDB table name"
  value       = module.camera_incidents_table.table_name
}

output "camera_incidents_table_arn" {
  description = "Camera Incidents DynamoDB table ARN"
  value       = module.camera_incidents_table.table_arn
}

# Timestream
output "timestream_database_name" {
  description = "Timestream database name"
  value       = aws_timestreamwrite_database.iot_metrics.database_name
}

output "timestream_database_arn" {
  description = "Timestream database ARN"
  value       = aws_timestreamwrite_database.iot_metrics.arn
}

output "timestream_tables" {
  description = "Timestream table names"
  value = {
    camera_metrics = aws_timestreamwrite_table.camera_metrics.table_name
    site_metrics   = aws_timestreamwrite_table.site_metrics.table_name
    system_metrics = aws_timestreamwrite_table.system_metrics.table_name
  }
}

output "camera_metrics_table_arn" {
  description = "Camera metrics table ARN"
  value       = aws_timestreamwrite_table.camera_metrics.arn
}

output "site_metrics_table_arn" {
  description = "Site metrics table ARN"
  value       = aws_timestreamwrite_table.site_metrics.arn
}

output "system_metrics_table_arn" {
  description = "System metrics table ARN"
  value       = aws_timestreamwrite_table.system_metrics.arn
}
