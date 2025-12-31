locals {
  product_name = "aismc"
  environment  = "dev"
  region       = data.aws_region.current.name

  tags = {
    Environment = local.environment
    Product     = local.product_name
    ManagedBy   = "Terraform"
    Project     = "AIOps-IoC"
    Layer       = "IoT-Core"
  }

  # MQTT topic structure
  mqtt_topics = {
    incidents = "cameras/+/incidents"
    registry  = "cameras/+/registry"
    metrics   = "cameras/+/metrics"
  }
}
