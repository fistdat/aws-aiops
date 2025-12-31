"""
Lambda function: GET /incidents
Query DynamoDB CameraIncidents table for incident list
"""
import json
import os
import boto3
from decimal import Decimal
from datetime import datetime, timedelta

# Initialize DynamoDB client
dynamodb = boto3.resource('dynamodb', region_name=os.environ['REGION'])
table = dynamodb.Table(os.environ['INCIDENTS_TABLE'])


class DecimalEncoder(json.JSONEncoder):
    """Helper class to convert DynamoDB Decimal to JSON"""
    def default(self, obj):
        if isinstance(obj, Decimal):
            return float(obj)
        return super(DecimalEncoder, self).default(obj)


def handler(event, context):
    """
    GET /incidents
    Query parameters:
    - site_id: Filter by site (optional)
    - entity_id: Filter by camera (optional)
    - status: Filter by status (active, resolved) (optional)
    - incident_type: Filter by type (camera_offline, etc.) (optional)
    - limit: Number of results (default: 100)
    - last_key: For pagination (optional)
    """
    try:
        # Parse query parameters
        params = event.get('queryStringParameters', {}) or {}
        site_id = params.get('site_id')
        entity_id = params.get('entity_id')
        status = params.get('status')
        incident_type = params.get('incident_type')
        limit = int(params.get('limit', 100))
        last_key = params.get('last_key')

        print(f"Query parameters: site_id={site_id}, entity_id={entity_id}, status={status}, type={incident_type}, limit={limit}")

        # Build query/scan kwargs
        kwargs = {
            'Limit': limit,
            'ScanIndexForward': False  # Sort by timestamp descending (newest first)
        }

        if last_key:
            kwargs['ExclusiveStartKey'] = json.loads(last_key)

        # Determine which index to use based on query parameters
        if site_id:
            kwargs['IndexName'] = 'site_id-timestamp-index'
            kwargs['KeyConditionExpression'] = 'site_id = :site_id'
            kwargs['ExpressionAttributeValues'] = {':site_id': site_id}
            response = table.query(**kwargs)
        elif entity_id:
            kwargs['IndexName'] = 'entity_id-timestamp-index'
            kwargs['KeyConditionExpression'] = 'entity_id = :entity_id'
            kwargs['ExpressionAttributeValues'] = {':entity_id': entity_id}
            response = table.query(**kwargs)
        elif status:
            kwargs['IndexName'] = 'status-timestamp-index'
            kwargs['KeyConditionExpression'] = '#status = :status'
            kwargs['ExpressionAttributeNames'] = {'#status': 'status'}
            kwargs['ExpressionAttributeValues'] = {':status': status}
            response = table.query(**kwargs)
        elif incident_type:
            kwargs['IndexName'] = 'incident_type-timestamp-index'
            kwargs['KeyConditionExpression'] = 'incident_type = :incident_type'
            kwargs['ExpressionAttributeValues'] = {':incident_type': incident_type}
            response = table.query(**kwargs)
        else:
            # No filter - scan all (not recommended for production with large data)
            response = table.scan(**kwargs)

        # Prepare response
        result = {
            'incidents': response.get('Items', []),
            'count': response.get('Count', 0)
        }

        if 'LastEvaluatedKey' in response:
            result['last_key'] = json.dumps(response['LastEvaluatedKey'], cls=DecimalEncoder)

        print(f"Returning {result['count']} incidents")

        return {
            'statusCode': 200,
            'headers': {
                'Content-Type': 'application/json',
                'Access-Control-Allow-Origin': '*',
                'Access-Control-Allow-Headers': 'Content-Type',
                'Access-Control-Allow-Methods': 'GET,OPTIONS'
            },
            'body': json.dumps(result, cls=DecimalEncoder)
        }

    except Exception as e:
        print(f"Error: {str(e)}")
        return {
            'statusCode': 500,
            'headers': {
                'Content-Type': 'application/json',
                'Access-Control-Allow-Origin': '*'
            },
            'body': json.dumps({'error': str(e)})
        }
