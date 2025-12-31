# IoT Rules Module

IoT Rules Engine configuration for routing MQTT messages to various AWS services.

## Purpose

Route IoT Core MQTT messages to:
- DynamoDB (device registry, incidents)
- Timestream (metrics)
- SNS (critical alerts)
- CloudWatch Logs (error handling)

## Resources Created

### IoT Topic Rules

1. **incidents_to_dynamodb**
   - Topic: `cameras/+/incidents`
   - Action: Write to DynamoDB CameraIncidents table

2. **registry_to_dynamodb**
   - Topic: `cameras/+/registry`
   - Action: Write to DynamoDB DeviceRegistry table

3. **critical_alerts_to_sns**
   - Topic: `cameras/+/incidents`
   - Filter: `WHERE incident_type = 'camera_offline' AND priority = 'critical'`
   - Action: Publish to SNS critical alerts topic

4. **metrics_to_timestream**
   - Topic: `cameras/+/metrics`
   - Action: Write to Timestream camera-metrics table

### SNS Topics

- **critical-alerts**: For urgent camera incidents
- **warning-alerts**: For warning-level events
- **operational-notifications**: For general notifications

## Usage

```bash
# Deploy
terraform init
terraform plan -out=tfplan
terraform apply tfplan

# Confirm SNS email subscription
# Check your email and confirm the subscription

# Test message publishing
../../scripts/test-iot-message.sh cameras/site-001/incidents

# View IoT Rules
aws iot list-topic-rules --region ap-southeast-1
aws iot get-topic-rule --rule-name aismc_dev_incidents_to_dynamodb

# Check CloudWatch Logs for rule processing
aws logs tail /aws/iot/rules/aismc-dev/errors --follow
```

## Outputs

- `iot_rules`: Map of IoT Rule ARNs
- `sns_topics`: Map of SNS Topic ARNs
- `critical_alerts_topic_arn`: ARN of critical alerts topic
- `iot_rules_error_log_group`: CloudWatch log group name

## Dependencies

- IAM roles (dev/0.iam_assume_role_terraform) - for IoT Core service role
- Data Layer (dev/3.data_layer) - for table names and database names

## Message Flow

```
IoT Device → MQTT Topic → IoT Rule → Target Service
                                    ├─→ DynamoDB
                                    ├─→ Timestream
                                    ├─→ SNS
                                    └─→ CloudWatch Logs (errors)
```

## Testing

Test message format for incidents:
```json
{
  "incident_id": "test-001",
  "site_id": "site-001",
  "entity_id": "camera-001",
  "incident_type": "camera_offline",
  "priority": "critical",
  "timestamp": "2025-12-29T10:00:00Z"
}
```

Publish test:
```bash
aws iot-data publish \
  --topic cameras/site-001/incidents \
  --payload file://test-incident.json \
  --region ap-southeast-1
```

Verify in DynamoDB:
```bash
aws dynamodb scan \
  --table-name aismc-dev-camera-incidents \
  --limit 10
```

## Cost

- **IoT Rules**: $0.15 per million rules triggered
- **SNS**: $0.50 per million publishes
- **CloudWatch Logs**: $0.50/GB ingested

Estimated: < $1/month during setup, ~$2/month in production
