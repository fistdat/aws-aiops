# AWS IoT Greengrass Thing Module

This Terraform module creates an AWS IoT Thing for Greengrass Core device with all necessary components:

## Features

- ✅ Creates IoT Thing with custom attributes
- ✅ Generates X.509 certificates and keys automatically
- ✅ Attaches certificate to Thing
- ✅ Attaches IoT Policy to certificate
- ✅ Adds Thing to specified Thing Group
- ✅ Stores credentials in AWS SSM Parameter Store (encrypted)
- ✅ Optionally saves credentials to local files for initial setup
- ✅ Downloads Amazon Root CA certificate

## Usage

```hcl
module "greengrass_core_hanoi" {
  source = "../../_module/aws/iot/greengrass_thing"

  thing_name       = "GreengrassCore-site001-hanoi"
  policy_name      = "greengrass-core-policy"
  thing_group_name = "Hanoi-Site-001"

  attributes = {
    site_id     = "site-001"
    location    = "Hanoi"
    environment = "dev"
  }

  save_credentials_locally = true
  credentials_output_path  = "./greengrass-credentials"

  tags = {
    Environment = "dev"
    Project     = "AIOps"
  }
}
```

## Inputs

| Name | Description | Type | Default | Required |
|------|-------------|------|---------|:--------:|
| thing_name | Name of the IoT Thing | `string` | n/a | yes |
| policy_name | IoT Policy to attach | `string` | n/a | yes |
| thing_group_name | Thing Group to join | `string` | n/a | yes |
| attributes | Thing attributes | `map(string)` | `{}` | no |
| save_credentials_locally | Save creds locally | `bool` | `true` | no |
| credentials_output_path | Local path for creds | `string` | `./greengrass-credentials` | no |
| tags | Resource tags | `map(string)` | `{}` | no |

## Outputs

| Name | Description |
|------|-------------|
| thing_name | Created Thing name |
| thing_arn | Thing ARN |
| certificate_arn | Certificate ARN |
| certificate_pem | Certificate PEM (sensitive) |
| private_key | Private key (sensitive) |
| iot_endpoint | IoT endpoint URL |
| ssm_cert_parameter | SSM parameter for cert |
| credentials_path | Local credentials path |

## Security

- Certificates are stored in AWS SSM Parameter Store as SecureString
- Local credential files have 0600 permissions (owner read/write only)
- Sensitive outputs are marked as sensitive in Terraform
- Certificates are automatically activated upon creation

## Post-Deployment

After running this module:

1. Retrieve credentials from SSM Parameter Store or local files
2. Install AWS IoT Greengrass on your device
3. Configure Greengrass with the generated credentials
4. Start Greengrass Core service

## Example: Retrieve Credentials from SSM

```bash
# Get certificate
aws ssm get-parameter \
  --name "/greengrass/GreengrassCore-site001-hanoi/cert-pem" \
  --with-decryption \
  --query 'Parameter.Value' \
  --output text > thingCert.crt

# Get private key
aws ssm get-parameter \
  --name "/greengrass/GreengrassCore-site001-hanoi/private-key" \
  --with-decryption \
  --query 'Parameter.Value' \
  --output text > privKey.key
```
