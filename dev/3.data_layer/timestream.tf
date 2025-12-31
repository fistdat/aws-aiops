# ============================================================================
# Timestream Database for Time-Series Metrics
# ============================================================================

# Timestream Database
resource "aws_timestreamwrite_database" "iot_metrics" {
  database_name = "${local.product_name}-${local.environment}-iot-metrics"

  tags = merge(local.tags, {
    Purpose = "IoT Time-Series Metrics"
  })
}

# Timestream Table for Camera Metrics
resource "aws_timestreamwrite_table" "camera_metrics" {
  database_name = aws_timestreamwrite_database.iot_metrics.database_name
  table_name    = "camera-metrics"

  retention_properties {
    memory_store_retention_period_in_hours  = 24   # 24 hours in memory
    magnetic_store_retention_period_in_days = 365  # 1 year in magnetic
  }

  magnetic_store_write_properties {
    enable_magnetic_store_writes = true
  }

  tags = merge(local.tags, {
    MetricType = "Camera"
    Description = "Individual camera performance metrics"
  })
}

# Timestream Table for Site Metrics
resource "aws_timestreamwrite_table" "site_metrics" {
  database_name = aws_timestreamwrite_database.iot_metrics.database_name
  table_name    = "site-metrics"

  retention_properties {
    memory_store_retention_period_in_hours  = 24
    magnetic_store_retention_period_in_days = 365
  }

  magnetic_store_write_properties {
    enable_magnetic_store_writes = true
  }

  tags = merge(local.tags, {
    MetricType = "Site"
    Description = "Site-level aggregated metrics"
  })
}

# Timestream Table for System Metrics
resource "aws_timestreamwrite_table" "system_metrics" {
  database_name = aws_timestreamwrite_database.iot_metrics.database_name
  table_name    = "system-metrics"

  retention_properties {
    memory_store_retention_period_in_hours  = 168  # 7 days in memory
    magnetic_store_retention_period_in_days = 730  # 2 years in magnetic
  }

  magnetic_store_write_properties {
    enable_magnetic_store_writes = true
  }

  tags = merge(local.tags, {
    MetricType = "System"
    Description = "Overall system health and performance metrics"
  })
}
