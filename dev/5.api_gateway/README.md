# API Gateway Module

REST API with Lambda functions for querying camera data and incidents.

## Purpose

Provide REST API endpoints for:
- Querying camera registry
- Retrieving incident history
- Dashboard backend

## Resources Created

### API Gateway

- REST API: `aismc-dev-aiops-api`
- Stage: `dev`
- Resources:
  - `/cameras` - Camera registry queries
  - `/incidents` - Incident queries
  - `/metrics` - Metrics (future)

### Lambda Functions

**get-cameras**
- Query DynamoDB DeviceRegistry
- Supports filtering by site_id
- Pagination support

**get-incidents**
- Query DynamoDB CameraIncidents
- Supports filtering by: site_id, entity_id, status, incident_type
- Sorted by timestamp (newest first)
- Pagination support

## Usage

```bash
# Deploy
terraform init
terraform plan -out=tfplan
terraform apply tfplan

# Get API endpoint
API_ENDPOINT=$(terraform output -raw api_gateway_endpoint)
echo $API_ENDPOINT

# Test endpoints
curl "${API_ENDPOINT}/cameras?limit=10"
curl "${API_ENDPOINT}/cameras?site_id=site-001&limit=100"
curl "${API_ENDPOINT}/incidents?limit=10"
curl "${API_ENDPOINT}/incidents?status=active"
curl "${API_ENDPOINT}/incidents?site_id=site-001&limit=50"
```

## Endpoints

### GET /cameras

**Query Parameters**:
- `site_id` (optional): Filter by site
- `limit` (optional): Number of results (default: 100)
- `last_key` (optional): Pagination token

**Response**:
```json
{
  "cameras": [...],
  "count": 10,
  "last_key": "..." // if more results available
}
```

### GET /incidents

**Query Parameters**:
- `site_id` (optional): Filter by site
- `entity_id` (optional): Filter by camera
- `status` (optional): Filter by status (active, resolved)
- `incident_type` (optional): Filter by type
- `limit` (optional): Number of results (default: 100)
- `last_key` (optional): Pagination token

**Response**:
```json
{
  "incidents": [...],
  "count": 10,
  "last_key": "..."
}
```

## Lambda Code

Lambda functions are in:
- `lambda/get_cameras/index.py`
- `lambda/get_incidents/index.py`

Automatically packaged by Terraform using `archive_file` data source.

## Outputs

- `api_gateway_endpoint`: Base URL for API
- `cameras_endpoint`: Full URL for /cameras
- `incidents_endpoint`: Full URL for /incidents
- `lambda_functions`: Map of Lambda function ARNs

## Dependencies

- IAM roles (dev/0.iam_assume_role_terraform) - for Lambda execution role
- Data Layer (dev/3.data_layer) - for table names

## CORS

CORS is enabled for all endpoints:
- `Access-Control-Allow-Origin: *`
- `Access-Control-Allow-Headers: Content-Type`
- `Access-Control-Allow-Methods: GET,OPTIONS`

## Authentication

Currently: None (public API)

TODO for production:
- Add API keys
- Implement JWT authentication
- Add rate limiting

## Monitoring

Lambda logs are in CloudWatch:
```bash
# View logs
aws logs tail /aws/lambda/aismc-dev-get-cameras --follow
aws logs tail /aws/lambda/aismc-dev-get-incidents --follow
```

API Gateway logs:
```bash
aws logs tail /aws/apigateway/aismc-dev --follow
```

## Cost

- **API Gateway**: Free tier (1M requests/month)
- **Lambda**: Free tier (1M requests/month, 400K GB-seconds)

Estimated: $0/month during setup (within free tier)
