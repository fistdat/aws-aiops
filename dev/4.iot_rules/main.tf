terraform {
  required_version = ">= 1.5.0"

  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
    }
  }

  # Uncomment after first apply to enable remote state
  # backend "s3" {
  #   bucket         = "aismc-nonprod-terraform-state"
  #   key            = "dev/iot-rules/terraform.tfstate"
  #   region         = "ap-southeast-1"
  #   encrypt        = true
  #   dynamodb_table = "terraform-state-lock"
  # }
}

# ============================================================================
# Data Sources - Get outputs from other modules
# ============================================================================

# Get IAM role ARNs
data "terraform_remote_state" "iam" {
  backend = "s3"
  config = {
    bucket = "aismc-platform-terraformstatefile-20251101-061100493617"
    key    = "aismc-dev/0.iam_assume_role_terraform/terraform.tfstate"
    region = "ap-southeast-1"
  }
}

# Get Data Layer outputs
data "terraform_remote_state" "data_layer" {
  backend = "s3"
  config = {
    bucket = "aismc-platform-terraformstatefile-20251101-061100493617"
    key    = "aismc-dev/3.data_layer/terraform.tfstate"
    region = "ap-southeast-1"
  }
}

# ============================================================================
# IoT Topic Rules
# ============================================================================

# Rule: Route Incidents to DynamoDB
resource "aws_iot_topic_rule" "incidents_to_dynamodb" {
  name        = "${local.product_name}_${local.environment}_incidents_to_dynamodb"
  description = "Route camera incidents to DynamoDB CameraIncidents table"
  enabled     = true
  sql         = "SELECT * FROM 'cameras/+/incidents'"
  sql_version = "2016-03-23"

  dynamodbv2 {
    role_arn = data.terraform_remote_state.iam.outputs.iot_core_service_role_arn

    put_item {
      table_name = data.terraform_remote_state.data_layer.outputs.camera_incidents_table_name
    }
  }

  error_action {
    cloudwatch_logs {
      log_group_name = aws_cloudwatch_log_group.iot_rules_errors.name
      role_arn       = data.terraform_remote_state.iam.outputs.iot_core_service_role_arn
    }
  }

  tags = local.tags
}

# Rule: Route Registry Updates to DynamoDB
resource "aws_iot_topic_rule" "registry_to_dynamodb" {
  name        = "${local.product_name}_${local.environment}_registry_to_dynamodb"
  description = "Route camera registry updates to DynamoDB DeviceRegistry table"
  enabled     = true
  sql         = "SELECT * FROM 'cameras/+/registry'"
  sql_version = "2016-03-23"

  dynamodbv2 {
    role_arn = data.terraform_remote_state.iam.outputs.iot_core_service_role_arn

    put_item {
      table_name = data.terraform_remote_state.data_layer.outputs.device_registry_table_name
    }
  }

  error_action {
    cloudwatch_logs {
      log_group_name = aws_cloudwatch_log_group.iot_rules_errors.name
      role_arn       = data.terraform_remote_state.iam.outputs.iot_core_service_role_arn
    }
  }

  tags = local.tags
}

# Rule: Critical Alerts to SNS
resource "aws_iot_topic_rule" "critical_alerts_to_sns" {
  name        = "${local.product_name}_${local.environment}_critical_alerts"
  description = "Send critical alerts to SNS topic"
  enabled     = true
  sql         = "SELECT * FROM 'cameras/+/incidents' WHERE incident_type = 'camera_offline' AND priority = 'critical'"
  sql_version = "2016-03-23"

  sns {
    role_arn       = data.terraform_remote_state.iam.outputs.iot_core_service_role_arn
    target_arn     = aws_sns_topic.critical_alerts.arn
    message_format = "JSON"
  }

  error_action {
    cloudwatch_logs {
      log_group_name = aws_cloudwatch_log_group.iot_rules_errors.name
      role_arn       = data.terraform_remote_state.iam.outputs.iot_core_service_role_arn
    }
  }

  tags = local.tags
}

# Rule: Metrics to Timestream
# COMMENTED OUT: Timestream not supported in ap-southeast-1 region
# resource "aws_iot_topic_rule" "metrics_to_timestream" {
#   name        = "${local.product_name}_${local.environment}_metrics_to_timestream"
#   description = "Route camera metrics to Timestream database"
#   enabled     = true
#   sql         = "SELECT * FROM 'cameras/+/metrics'"
#   sql_version = "2016-03-23"

#   timestream {
#     role_arn      = data.terraform_remote_state.iam.outputs.iot_core_service_role_arn
#     database_name = data.terraform_remote_state.data_layer.outputs.timestream_database_name
#     table_name    = data.terraform_remote_state.data_layer.outputs.timestream_tables["camera_metrics"]

#     dimension {
#       name  = "site_id"
#       value = "$${site_id}"
#     }

#     dimension {
#       name  = "entity_id"
#       value = "$${entity_id}"
#     }
#   }

#   error_action {
#     cloudwatch_logs {
#       log_group_name = aws_cloudwatch_log_group.iot_rules_errors.name
#       role_arn       = data.terraform_remote_state.iam.outputs.iot_core_service_role_arn
#     }
#   }

#   tags = local.tags
# }

# ============================================================================
# CloudWatch Log Group for Rule Errors
# ============================================================================

resource "aws_cloudwatch_log_group" "iot_rules_errors" {
  name              = "/aws/iot/rules/${local.product_name}-${local.environment}/errors"
  retention_in_days = 30

  tags = local.tags
}
