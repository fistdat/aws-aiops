# ============================================================================
# DynamoDB Tables
# ============================================================================

# DeviceRegistry Table - Camera catalog (static, updated 1x/day)
module "device_registry_table" {
  source = "../../_module/aws/data/dynamodb"

  table_name   = "${local.product_name}-${local.environment}-device-registry"
  billing_mode = "PAY_PER_REQUEST"
  hash_key     = "entity_id"

  attributes = [
    {
      name = "entity_id"
      type = "S"
    },
    {
      name = "site_id"
      type = "S"
    },
    {
      name = "device_type"
      type = "S"
    }
  ]

  global_secondary_indexes = [
    {
      name            = "site_id-index"
      hash_key        = "site_id"
      range_key       = ""
      projection_type = "ALL"
    },
    {
      name            = "device_type-index"
      hash_key        = "device_type"
      range_key       = ""
      projection_type = "ALL"
    }
  ]

  point_in_time_recovery = true

  tags = merge(local.tags, {
    Purpose = "Camera Device Registry"
    DataType = "Static Catalog"
  })
}

# CameraIncidents Table - Real-time incident tracking
module "camera_incidents_table" {
  source = "../../_module/aws/data/dynamodb"

  table_name   = "${local.product_name}-${local.environment}-camera-incidents"
  billing_mode = "PAY_PER_REQUEST"
  hash_key     = "incident_id"
  range_key    = "timestamp"

  attributes = [
    {
      name = "incident_id"
      type = "S"
    },
    {
      name = "timestamp"
      type = "S"
    },
    {
      name = "site_id"
      type = "S"
    },
    {
      name = "entity_id"
      type = "S"
    },
    {
      name = "incident_type"
      type = "S"
    },
    {
      name = "status"
      type = "S"
    }
  ]

  global_secondary_indexes = [
    {
      name            = "site_id-timestamp-index"
      hash_key        = "site_id"
      range_key       = "timestamp"
      projection_type = "ALL"
    },
    {
      name            = "entity_id-timestamp-index"
      hash_key        = "entity_id"
      range_key       = "timestamp"
      projection_type = "ALL"
    },
    {
      name            = "incident_type-timestamp-index"
      hash_key        = "incident_type"
      range_key       = "timestamp"
      projection_type = "ALL"
    },
    {
      name            = "status-timestamp-index"
      hash_key        = "status"
      range_key       = "timestamp"
      projection_type = "ALL"
    }
  ]

  ttl_attribute_name     = "ttl"
  point_in_time_recovery = true

  tags = merge(local.tags, {
    Purpose = "Camera Incident Tracking"
    DataType = "Real-time Events"
  })
}

# ============================================================================
# v2.0 Architecture Tables - Batch Analytics
# ============================================================================

# DeviceInventory Table - Daily device inventory snapshots
module "device_inventory_table" {
  source = "../../_module/aws/data/dynamodb"

  table_name   = "${local.product_name}-${local.environment}-device-inventory"
  billing_mode = "PAY_PER_REQUEST"
  hash_key     = "site_id"
  range_key    = "timestamp"

  attributes = [
    {
      name = "site_id"
      type = "S"
    },
    {
      name = "timestamp"
      type = "S"
    },
    {
      name = "date"
      type = "S"
    }
  ]

  global_secondary_indexes = [
    {
      name            = "date-index"
      hash_key        = "date"
      range_key       = ""
      projection_type = "ALL"
    }
  ]

  ttl_attribute_name     = "ttl"  # Auto-delete old snapshots (90+ days)
  point_in_time_recovery = true

  tags = merge(local.tags, {
    Purpose      = "Device Inventory Snapshots"
    DataType     = "Daily Aggregates"
    Architecture = "v2.0"
  })
}

# IncidentAnalytics Table - Hourly incident analytics summaries
module "incident_analytics_table" {
  source = "../../_module/aws/data/dynamodb"

  table_name   = "${local.product_name}-${local.environment}-incident-analytics"
  billing_mode = "PAY_PER_REQUEST"
  hash_key     = "site_id"
  range_key    = "timestamp"

  attributes = [
    {
      name = "site_id"
      type = "S"
    },
    {
      name = "timestamp"
      type = "S"
    },
    {
      name = "hour"
      type = "S"
    }
  ]

  global_secondary_indexes = [
    {
      name            = "hour-index"
      hash_key        = "hour"
      range_key       = ""
      projection_type = "ALL"
    }
  ]

  ttl_attribute_name     = "ttl"  # Auto-delete old analytics (90+ days)
  point_in_time_recovery = true

  tags = merge(local.tags, {
    Purpose      = "Incident Analytics"
    DataType     = "Hourly Aggregates"
    Architecture = "v2.0"
  })
}

# ChatHistory Table - Bedrock AI conversation history (Phase 3)
module "chat_history_table" {
  source = "../../_module/aws/data/dynamodb"

  table_name   = "${local.product_name}-${local.environment}-chat-history"
  billing_mode = "PAY_PER_REQUEST"
  hash_key     = "user_id"
  range_key    = "timestamp"

  attributes = [
    {
      name = "user_id"
      type = "S"
    },
    {
      name = "timestamp"
      type = "S"
    },
    {
      name = "conversation_id"
      type = "S"
    }
  ]

  global_secondary_indexes = [
    {
      name            = "conversation_id-index"
      hash_key        = "conversation_id"
      range_key       = "timestamp"
      projection_type = "ALL"
    }
  ]

  ttl_attribute_name     = "ttl"  # Auto-delete old chats (90+ days)
  point_in_time_recovery = false  # Not critical data

  tags = merge(local.tags, {
    Purpose      = "Bedrock AI Chat History"
    DataType     = "Conversation Logs"
    Architecture = "v2.0 - Phase 3"
  })
}
