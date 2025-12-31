# ============================================================================
# SNS Topics for Alerting
# ============================================================================

# SNS Topic for Critical Alerts
resource "aws_sns_topic" "critical_alerts" {
  name         = "${local.product_name}-${local.environment}-critical-alerts"
  display_name = "AIOps IoC Critical Alerts"

  tags = merge(local.tags, {
    AlertLevel = "Critical"
    Purpose    = "Critical camera incidents requiring immediate attention"
  })
}

# SNS Topic for Warning Alerts
resource "aws_sns_topic" "warning_alerts" {
  name         = "${local.product_name}-${local.environment}-warning-alerts"
  display_name = "AIOps IoC Warning Alerts"

  tags = merge(local.tags, {
    AlertLevel = "Warning"
    Purpose    = "Warning-level incidents"
  })
}

# SNS Topic for Operational Notifications
resource "aws_sns_topic" "operational_notifications" {
  name         = "${local.product_name}-${local.environment}-operational-notifications"
  display_name = "AIOps IoC Operational Notifications"

  tags = merge(local.tags, {
    AlertLevel = "Info"
    Purpose    = "General operational notifications"
  })
}

# ============================================================================
# SNS Topic Subscriptions (Email)
# ============================================================================

# Email subscription for critical alerts (requires manual confirmation)
resource "aws_sns_topic_subscription" "critical_email" {
  topic_arn = aws_sns_topic.critical_alerts.arn
  protocol  = "email"
  endpoint  = var.alert_email
}

# Email subscription for warning alerts (optional)
# Uncomment if needed
# resource "aws_sns_topic_subscription" "warning_email" {
#   topic_arn = aws_sns_topic.warning_alerts.arn
#   protocol  = "email"
#   endpoint  = var.alert_email
# }
