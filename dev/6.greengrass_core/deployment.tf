# ============================================================================
# Greengrass Deployment Configuration
# ============================================================================
# This file manages Greengrass Core device deployments using Infrastructure as Code
# ============================================================================

# Get credentials endpoint for the region
data "aws_iot_endpoint" "credentials" {
  endpoint_type = "iot:CredentialProvider"
}

# ============================================================================
# Greengrass Deployment for Hanoi Site 001
# ============================================================================
# Since AWS provider doesn't support greengrassv2_deployment resource yet,
# we use AWS CLI with null_resource to create the deployment
# ============================================================================

# Create deployment configuration file
resource "local_file" "deployment_config" {
  content = jsonencode({
    targetArn = module.greengrass_core_hanoi_site_001.thing_arn
    deploymentName = "greengrass-core-config-${local.environment}-${formatdate("YYYYMMDDhhmmss", timestamp())}"
    components = {
      "aws.greengrass.Nucleus" = {
        componentVersion = "2.16.0"
        configurationUpdate = {
          merge = jsonencode({
            awsRegion = local.region
            iotRoleAlias = "GreengrassCoreTokenExchangeRoleAlias"
            iotDataEndpoint = module.greengrass_core_hanoi_site_001.iot_endpoint
            iotCredEndpoint = data.aws_iot_endpoint.credentials.endpoint_address
            componentStoreMaxSizeBytes = "10000000000"
            deploymentPollingFrequencySeconds = 15
            fleetStatus = {
              periodicStatusPublishIntervalSeconds = 86400
            }
          })
        }
      }
    }
    deploymentPolicies = {
      componentUpdatePolicy = {
        timeoutInSeconds = 300
        action = "NOTIFY_COMPONENTS"
      }
      configurationValidationPolicy = {
        timeoutInSeconds = 300
      }
      failureHandlingPolicy = "ROLLBACK"
    }
  })

  filename = "${path.module}/greengrass-deployment.json"
  file_permission = "0644"
}

# Create Greengrass deployment using AWS CLI
resource "null_resource" "greengrass_deployment" {
  triggers = {
    thing_arn = module.greengrass_core_hanoi_site_001.thing_arn
    config_hash = sha256(local_file.deployment_config.content)
  }

  provisioner "local-exec" {
    command = <<-EOT
      aws greengrassv2 create-deployment \
        --cli-input-json file://${local_file.deployment_config.filename} \
        --region ${local.region} \
        --tags Environment=${local.environment},Product=${local.product_name},ManagedBy=Terraform,DeploymentType=CoreConfiguration,SiteId=site-001 \
        > ${path.module}/deployment-result.json
    EOT
  }

  depends_on = [
    module.greengrass_core_hanoi_site_001,
    local_file.deployment_config
  ]
}

# ============================================================================
# Outputs for Deployment
# ============================================================================

output "deployment_config_file" {
  description = "Path to deployment configuration file"
  value       = local_file.deployment_config.filename
}

output "deployment_result_file" {
  description = "Path to deployment result file"
  value       = "${path.module}/deployment-result.json"
}

output "credentials_endpoint" {
  description = "IoT Credentials Provider endpoint"
  value       = data.aws_iot_endpoint.credentials.endpoint_address
}

output "deployment_command" {
  description = "Command to check deployment status"
  value       = "aws greengrassv2 list-deployments --target-arn ${module.greengrass_core_hanoi_site_001.thing_arn} --region ${local.region}"
}
