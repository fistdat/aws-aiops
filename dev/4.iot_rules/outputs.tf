# IoT Rules
output "iot_rules" {
  description = "IoT Rule names and ARNs"
  value = {
    incidents_to_dynamodb  = aws_iot_topic_rule.incidents_to_dynamodb.arn
    registry_to_dynamodb   = aws_iot_topic_rule.registry_to_dynamodb.arn
    critical_alerts_to_sns = aws_iot_topic_rule.critical_alerts_to_sns.arn
    # metrics_to_timestream disabled - Timestream not supported in ap-southeast-1
  }
}

# SNS Topics
output "sns_topics" {
  description = "SNS topic ARNs"
  value = {
    critical_alerts           = aws_sns_topic.critical_alerts.arn
    warning_alerts            = aws_sns_topic.warning_alerts.arn
    operational_notifications = aws_sns_topic.operational_notifications.arn
  }
}

output "critical_alerts_topic_arn" {
  description = "ARN of critical alerts SNS topic"
  value       = aws_sns_topic.critical_alerts.arn
}

output "warning_alerts_topic_arn" {
  description = "ARN of warning alerts SNS topic"
  value       = aws_sns_topic.warning_alerts.arn
}

output "operational_notifications_topic_arn" {
  description = "ARN of operational notifications SNS topic"
  value       = aws_sns_topic.operational_notifications.arn
}

# CloudWatch Log Group
output "iot_rules_error_log_group" {
  description = "CloudWatch log group for IoT Rules errors"
  value       = aws_cloudwatch_log_group.iot_rules_errors.name
}
