# IoT Core Module

AWS IoT Core infrastructure including Thing Groups, IoT Policies, and certificate management.

## Purpose

Setup AWS IoT Core infrastructure for managing Greengrass Core devices across multiple sites in Vietnam.

## Resources Created

- **Thing Groups**: Hierarchical organization (Vietnam → Regions → Sites)
  - Vietnam (root)
  - Northern-Region, Central-Region, Southern-Region
  - Hanoi-Site-001 (pilot)

- **IoT Policies**:
  - greengrass-core-policy: Permissions for Greengrass devices
  - readonly-policy: Read-only access for monitoring

- **Certificate Infrastructure**:
  - S3 bucket for certificate metadata
  - DynamoDB table for certificate tracking

## Usage

```bash
# Deploy
terraform init
terraform plan -out=tfplan
terraform apply tfplan

# View outputs
terraform output
terraform output iot_data_endpoint

# Verify Thing Groups
aws iot list-thing-groups --region ap-southeast-1
aws iot describe-thing-group --thing-group-name Vietnam
```

## Outputs

- `vietnam_thing_group_arn`: Root Thing Group ARN
- `hanoi_site_001_thing_group_arn`: Pilot site Thing Group ARN
- `greengrass_core_policy_name`: Policy name for Greengrass
- `iot_data_endpoint`: MQTT endpoint for device connections
- `iot_credentials_endpoint`: Credentials provider endpoint
- `certificate_bucket_name`: S3 bucket for cert metadata

## Dependencies

- IAM roles (dev/0.iam_assume_role_terraform)

## Next Steps

After deployment:
1. Create IoT certificates: `../../scripts/create-iot-certificate.sh site-001`
2. Deploy Greengrass Core to pilot site
3. Attach certificates to devices
