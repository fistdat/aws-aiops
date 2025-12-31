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
