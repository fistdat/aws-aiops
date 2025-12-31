# Greengrass Core Setup Instructions

**Thing Name**: `${thing_name}`
**IoT Endpoint**: `${iot_endpoint}`
**Region**: `${region}`
**Thing Group**: `${thing_group}`

---

## 📋 Overview

This document guides you through setting up AWS IoT Greengrass Core with the newly created Thing and certificates.

---

## 🔐 Credentials Location

Your credentials have been saved to:
```
${credentials_path}/
├── ${thing_name}-certificate.pem.crt
├── ${thing_name}-private.pem.key
├── ${thing_name}-public.pem.key
└── AmazonRootCA1.pem
```

**Alternatively**, retrieve from AWS SSM Parameter Store:
```bash
# Certificate
aws ssm get-parameter \
  --name "${ssm_cert_param}" \
  --with-decryption \
  --query 'Parameter.Value' \
  --output text > thingCert.crt

# Private Key
aws ssm get-parameter \
  --name "${ssm_key_param}" \
  --with-decryption \
  --query 'Parameter.Value' \
  --output text > privKey.key
```

---

## 🚀 Setup Steps

### Step 1: Stop Current Greengrass Service

```bash
sudo systemctl stop greengrass.service
```

### Step 2: Backup Current Configuration

```bash
sudo cp -r /greengrass/v2 /greengrass/v2.backup-$(date +%Y%m%d-%H%M%S)
```

### Step 3: Copy New Certificates

Use the provided script:

```bash
sudo ./copy-credentials-to-greengrass.sh
```

Or manually:

```bash
# Copy certificate
sudo cp ${credentials_path}/${thing_name}-certificate.pem.crt \
        /greengrass/v2/thingCert.crt

# Copy private key
sudo cp ${credentials_path}/${thing_name}-private.pem.key \
        /greengrass/v2/privKey.key

# Copy Root CA
sudo cp ${credentials_path}/AmazonRootCA1.pem \
        /greengrass/v2/rootCA.pem

# Set permissions
sudo chown root:ggc_group /greengrass/v2/thingCert.crt
sudo chown root:ggc_group /greengrass/v2/privKey.key
sudo chown root:ggc_group /greengrass/v2/rootCA.pem
sudo chmod 644 /greengrass/v2/thingCert.crt
sudo chmod 640 /greengrass/v2/privKey.key
sudo chmod 644 /greengrass/v2/rootCA.pem
```

### Step 4: Update Greengrass Configuration

Edit the effective configuration:

```bash
sudo nano /greengrass/v2/config/effectiveConfig.yaml
```

Update the following fields:

```yaml
services:
  aws.greengrass.Nucleus:
    configuration:
      awsRegion: "${region}"
      iotRoleAlias: "GreengrassCoreTokenExchangeRoleAlias"
      iotDataEndpoint: "${iot_endpoint}"
      iotCredEndpoint: "REPLACE_WITH_CREDENTIALS_ENDPOINT"
```

Get the credentials endpoint:
```bash
aws iot describe-endpoint --endpoint-type iot:CredentialProvider --region ${region}
```

### Step 5: Update Thing Name in Component Configurations

If you have components that reference the old thing name, update them:

```bash
# Find components referencing old thing name
sudo grep -r "GreengrassCore-datht9" /greengrass/v2/

# Update as needed
```

### Step 6: Start Greengrass Service

```bash
sudo systemctl start greengrass.service
```

### Step 7: Verify Status

```bash
# Check service status
sudo systemctl status greengrass.service

# Check component status
sudo /greengrass/v2/bin/greengrass-cli component list

# Check logs
sudo tail -f /greengrass/v2/logs/greengrass.log
```

---

## ✅ Verification Checklist

- [ ] Greengrass service is running
- [ ] Components are in RUNNING state (not BROKEN)
- [ ] No DNS resolution errors in logs
- [ ] Thing shows as connected in AWS IoT Console
- [ ] Device Shadow is syncing

---

## 🔍 Troubleshooting

### Issue: DNS Resolution Failed

**Symptom**: `AWS_IO_DNS_QUERY_FAILED: A query to dns failed to resolve`

**Solution**:
1. Verify internet connectivity
2. Check DNS settings: `cat /etc/resolv.conf`
3. Test endpoint resolution: `nslookup ${iot_endpoint}`

### Issue: Certificate Authentication Failed

**Symptom**: `TLS handshake failed` or `certificate verify failed`

**Solution**:
1. Verify certificate permissions (640 for privKey.key)
2. Check certificate is active in IoT Console
3. Verify policy is attached to certificate

### Issue: Thing Not Found

**Symptom**: `Thing not found` errors

**Solution**:
1. Verify thing exists: `aws iot describe-thing --thing-name ${thing_name} --region ${region}`
2. Check thing is in correct Thing Group
3. Verify configuration file has correct thing name

---

## 📊 AWS Console Verification

### Check Thing Status:
1. Go to AWS IoT Console
2. Navigate to: Manage → Things
3. Find: `${thing_name}`
4. Verify:
   - Status: Active
   - Certificate attached
   - Policy attached
   - Thing Group: `${thing_group}`

### Check Device Shadow:
1. In Thing details, go to Device Shadows tab
2. Verify shadow is updating

---

## 🔗 Useful Commands

```bash
# Get IoT endpoint
aws iot describe-endpoint --endpoint-type iot:Data-ATS --region ${region}

# Describe thing
aws iot describe-thing --thing-name ${thing_name} --region ${region}

# List certificates attached to thing
aws iot list-thing-principals --thing-name ${thing_name} --region ${region}

# Check component logs
sudo /greengrass/v2/bin/greengrass-cli logs get --log-group com.example.DeviceShadow
```

---

## 📞 Support

For issues, check:
- Greengrass logs: `/greengrass/v2/logs/`
- AWS IoT Console activity logs
- CloudWatch Logs

---

**Certificate ARN**: `${cert_arn}`
**Generated**: $(date)
