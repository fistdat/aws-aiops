"""
Lambda function: GET /cameras
Query DynamoDB DeviceRegistry table for camera list
"""
import json
import os
import boto3
from decimal import Decimal

# Initialize DynamoDB client
dynamodb = boto3.resource('dynamodb', region_name=os.environ['REGION'])
table = dynamodb.Table(os.environ['DEVICE_REGISTRY_TABLE'])


class DecimalEncoder(json.JSONEncoder):
    """Helper class to convert DynamoDB Decimal to JSON"""
    def default(self, obj):
        if isinstance(obj, Decimal):
            return float(obj)
        return super(DecimalEncoder, self).default(obj)


def handler(event, context):
    """
    GET /cameras
    Query parameters:
    - site_id: Filter by site (optional)
    - limit: Number of results (default: 100)
    - last_key: For pagination (optional)
    """
    try:
        # Parse query parameters
        params = event.get('queryStringParameters', {}) or {}
        site_id = params.get('site_id')
        limit = int(params.get('limit', 100))
        last_key = params.get('last_key')

        print(f"Query parameters: site_id={site_id}, limit={limit}")

        # Build query/scan kwargs
        scan_kwargs = {
            'Limit': limit
        }

        if last_key:
            scan_kwargs['ExclusiveStartKey'] = json.loads(last_key)

        # Query by site_id if provided, otherwise scan
        if site_id:
            scan_kwargs['IndexName'] = 'site_id-index'
            scan_kwargs['KeyConditionExpression'] = 'site_id = :site_id'
            scan_kwargs['ExpressionAttributeValues'] = {':site_id': site_id}
            response = table.query(**scan_kwargs)
        else:
            response = table.scan(**scan_kwargs)

        # Prepare response
        result = {
            'cameras': response.get('Items', []),
            'count': response.get('Count', 0)
        }

        if 'LastEvaluatedKey' in response:
            result['last_key'] = json.dumps(response['LastEvaluatedKey'], cls=DecimalEncoder)

        print(f"Returning {result['count']} cameras")

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
