# Greengrass Core Thing Deployment

This module deploys AWS IoT Things for Greengrass Core devices.

## Current Deployment

- **Hanoi Site 001**: Pilot site with 15,000 cameras
  - Thing Name: `GreengrassCore-site001-hanoi`
  - Thing Group: `Hanoi-Site-001`
  - Policy: `greengrass-core-policy`

## Prerequisites

Before running this module:

1. ✅ `dev/2.iot_core` must be deployed (creates Thing Groups and Policies)
2. ✅ AWS CLI configured with ap-southeast-1 region
3. ✅ Terraform >= 1.5.0 installed

## Deployment Steps

### 1. Initialize Terraform

```bash
cd /home/sysadmin/2025/aismc/aws-aiops/dev/6.greengrass_core
terraform init
```

### 2. Review Plan

```bash
terraform plan
```

Expected resources to create:
- 1 IoT Thing
- 1 IoT Certificate
- 1 Thing-Certificate attachment
- 1 Certificate-Policy attachment
- 1 Thing Group membership
- 3 SSM Parameters (cert, private key, public key)
- 4 Local files (credentials + setup scripts)

### 3. Apply Configuration

```bash
terraform apply
```

Review the plan and type `yes` to proceed.

### 4. View Outputs

```bash
terraform output
```

Or for sensitive outputs:
```bash
terraform output -json | jq
```

## Post-Deployment

After successful deployment:

### 1. Read Setup Instructions

```bash
cat GREENGRASS-SETUP-INSTRUCTIONS.md
```

### 2. Copy Credentials to Greengrass

```bash
sudo ./copy-credentials-to-greengrass.sh
```

### 3. Update Greengrass Configuration

See `GREENGRASS-SETUP-INSTRUCTIONS.md` for detailed steps.

## Files Generated

After `terraform apply`, you'll have:

```
dev/6.greengrass_core/
├── greengrass-credentials/
│   ├── GreengrassCore-site001-hanoi-certificate.pem.crt
│   ├── GreengrassCore-site001-hanoi-private.pem.key
│   ├── GreengrassCore-site001-hanoi-public.pem.key
│   └── AmazonRootCA1.pem
├── GREENGRASS-SETUP-INSTRUCTIONS.md
├── copy-credentials-to-greengrass.sh
└── (Terraform files)
```

## Credentials Security

Credentials are stored securely in multiple locations:

1. **AWS SSM Parameter Store** (encrypted, recommended for production)
   - `/greengrass/GreengrassCore-site001-hanoi/cert-pem`
   - `/greengrass/GreengrassCore-site001-hanoi/private-key`

2. **Local Files** (for initial setup only)
   - `greengrass-credentials/` directory
   - File permissions: 0600 (owner read/write only)

⚠️ **Important**: Local credential files should be deleted after initial setup or stored securely.

## Troubleshooting

### Issue: Thing Group not found

**Solution**: Deploy `dev/2.iot_core` first:
```bash
cd ../2.iot_core
terraform apply
```

### Issue: Policy not found

**Solution**: Verify policy exists:
```bash
aws iot get-policy --policy-name greengrass-core-policy --region ap-southeast-1
```

### Issue: Credentials not saved locally

**Solution**: Check variable `save_credentials_locally = true` in module call.

## Cleanup

To remove all resources:

```bash
terraform destroy
```

⚠️ **Warning**: This will:
- Delete the IoT Thing
- Revoke and delete certificates
- Remove SSM parameters
- Keep local credential files (manual deletion required)

## Module Dependencies

```
dev/2.iot_core (Thing Groups, Policies)
    ↓
dev/6.greengrass_core (Things, Certificates)
```

## Next Steps

After Greengrass Core is connected:

1. Deploy Greengrass Components:
   - Camera Registry Sync Service
   - Incident Message Forwarder

2. Configure local SQLite database

3. Test end-to-end data flow

## Support

For issues, check:
- Terraform state: `terraform show`
- AWS IoT Console: https://ap-southeast-1.console.aws.amazon.com/iot/home
- Greengrass logs: `/greengrass/v2/logs/`
