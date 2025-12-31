# Data sources for AWS account and region information
data "aws_caller_identity" "current" {}

data "aws_region" "current" {}

# IoT endpoints
data "aws_iot_endpoint" "data" {
  endpoint_type = "iot:Data-ATS"
}

data "aws_iot_endpoint" "credentials" {
  endpoint_type = "iot:CredentialProvider"
}
