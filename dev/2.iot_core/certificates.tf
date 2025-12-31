# ============================================================================
# Certificate Infrastructure
# ============================================================================

# Note: Actual X.509 certificates are created during device provisioning
# This file creates supporting infrastructure for certificate management

# S3 bucket for storing certificate metadata (optional)
resource "aws_s3_bucket" "iot_certificates" {
  bucket = "${local.product_name}-${local.environment}-iot-certificates"

  tags = merge(local.tags, {
    Purpose = "IoT Certificate Metadata Storage"
  })
}

resource "aws_s3_bucket_versioning" "iot_certificates" {
  bucket = aws_s3_bucket.iot_certificates.id

  versioning_configuration {
    status = "Enabled"
  }
}

resource "aws_s3_bucket_server_side_encryption_configuration" "iot_certificates" {
  bucket = aws_s3_bucket.iot_certificates.id

  rule {
    apply_server_side_encryption_by_default {
      sse_algorithm = "AES256"
    }
  }
}

resource "aws_s3_bucket_public_access_block" "iot_certificates" {
  bucket = aws_s3_bucket.iot_certificates.id

  block_public_acls       = true
  block_public_policy     = true
  ignore_public_acls      = true
  restrict_public_buckets = true
}

# DynamoDB table for certificate tracking
resource "aws_dynamodb_table" "certificate_registry" {
  name         = "${local.product_name}-${local.environment}-certificate-registry"
  billing_mode = "PAY_PER_REQUEST"
  hash_key     = "certificate_id"
  range_key    = "thing_name"

  attribute {
    name = "certificate_id"
    type = "S"
  }

  attribute {
    name = "thing_name"
    type = "S"
  }

  attribute {
    name = "site_id"
    type = "S"
  }

  attribute {
    name = "status"
    type = "S"
  }

  global_secondary_index {
    name            = "site_id-index"
    hash_key        = "site_id"
    projection_type = "ALL"
  }

  global_secondary_index {
    name            = "status-index"
    hash_key        = "status"
    projection_type = "ALL"
  }

  ttl {
    attribute_name = "ttl"
    enabled        = true
  }

  point_in_time_recovery {
    enabled = true
  }

  tags = merge(local.tags, {
    Purpose = "Track IoT Certificates"
  })
}
