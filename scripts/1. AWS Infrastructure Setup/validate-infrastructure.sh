#!/bin/bash
set -e

# Infrastructure Validation Script
# Usage: ./scripts/validate-infrastructure.sh

REGION="ap-southeast-1"
ENVIRONMENT="dev"
PRODUCT="aismc"

GREEN='\033[0;32m'
RED='\033[0;31m'
NC='\033[0m'

function check_pass() {
    echo -e "${GREEN}✓${NC} $1"
}

function check_fail() {
    echo -e "${RED}✗${NC} $1"
    FAILED=true
}

FAILED=false

echo "=================================="
echo "Infrastructure Validation"
echo "=================================="

# Check Thing Groups
echo ""
echo "Checking Thing Groups..."
if aws iot describe-thing-group --thing-group-name Vietnam --region ${REGION} > /dev/null 2>&1; then
    check_pass "Thing Group 'Vietnam' exists"
else
    check_fail "Thing Group 'Vietnam' not found"
fi

if aws iot describe-thing-group --thing-group-name Hanoi-Site-001 --region ${REGION} > /dev/null 2>&1; then
    check_pass "Thing Group 'Hanoi-Site-001' exists"
else
    check_fail "Thing Group 'Hanoi-Site-001' not found"
fi

# Check IoT Policies
echo ""
echo "Checking IoT Policies..."
if aws iot get-policy --policy-name ${PRODUCT}-${ENVIRONMENT}-greengrass-core-policy --region ${REGION} > /dev/null 2>&1; then
    check_pass "IoT Policy 'greengrass-core-policy' exists"
else
    check_fail "IoT Policy 'greengrass-core-policy' not found"
fi

# Check DynamoDB Tables
echo ""
echo "Checking DynamoDB Tables..."
if aws dynamodb describe-table --table-name ${PRODUCT}-${ENVIRONMENT}-device-registry --region ${REGION} > /dev/null 2>&1; then
    check_pass "DynamoDB table 'device-registry' exists"
else
    check_fail "DynamoDB table 'device-registry' not found"
fi

if aws dynamodb describe-table --table-name ${PRODUCT}-${ENVIRONMENT}-camera-incidents --region ${REGION} > /dev/null 2>&1; then
    check_pass "DynamoDB table 'camera-incidents' exists"
else
    check_fail "DynamoDB table 'camera-incidents' not found"
fi

# Check Timestream
echo ""
echo "Checking Timestream Database..."
if aws timestream-write describe-database --database-name ${PRODUCT}-${ENVIRONMENT}-iot-metrics --region ${REGION} > /dev/null 2>&1; then
    check_pass "Timestream database 'iot-metrics' exists"
else
    check_fail "Timestream database 'iot-metrics' not found"
fi

# Check IoT Rules
echo ""
echo "Checking IoT Rules..."
RULE_COUNT=$(aws iot list-topic-rules --region ${REGION} --query 'rules[?starts_with(ruleName, `aismc_dev`)]' --output json 2>/dev/null | jq length || echo "0")
if [ "$RULE_COUNT" -ge "3" ]; then
    check_pass "IoT Rules configured (count: ${RULE_COUNT})"
else
    check_fail "Insufficient IoT Rules (expected: 3+, found: ${RULE_COUNT})"
fi

# Check SNS Topics
echo ""
echo "Checking SNS Topics..."
SNS_TOPICS=$(aws sns list-topics --region ${REGION} --query 'Topics[?contains(TopicArn, `aismc-dev`)]' --output json 2>/dev/null | jq length || echo "0")
if [ "$SNS_TOPICS" -ge "3" ]; then
    check_pass "SNS topics configured (count: ${SNS_TOPICS})"
else
    check_fail "Insufficient SNS topics (expected: 3, found: ${SNS_TOPICS})"
fi

# Check API Gateway
echo ""
echo "Checking API Gateway..."
cd dev/5.api_gateway
API_ID=$(terraform output -raw api_gateway_id 2>/dev/null || echo "")
if [ -n "$API_ID" ]; then
    check_pass "API Gateway deployed (ID: ${API_ID})"

    # Test API endpoint
    API_ENDPOINT=$(terraform output -raw api_gateway_endpoint 2>/dev/null || echo "")
    if [ -n "$API_ENDPOINT" ]; then
        HTTP_CODE=$(curl -s -o /dev/null -w "%{http_code}" "${API_ENDPOINT}/cameras?limit=10" 2>/dev/null || echo "000")
        if [ "$HTTP_CODE" = "200" ]; then
            check_pass "API Gateway endpoint accessible (HTTP ${HTTP_CODE})"
        else
            check_fail "API Gateway endpoint failed (HTTP ${HTTP_CODE})"
        fi
    fi
else
    check_fail "API Gateway not found"
fi
cd ../..

# Check Lambda Functions
echo ""
echo "Checking Lambda Functions..."
LAMBDA_COUNT=$(aws lambda list-functions --region ${REGION} --query 'Functions[?starts_with(FunctionName, `aismc-dev`)]' --output json 2>/dev/null | jq length || echo "0")
if [ "$LAMBDA_COUNT" -ge "2" ]; then
    check_pass "Lambda functions deployed (count: ${LAMBDA_COUNT})"
else
    check_fail "Insufficient Lambda functions (expected: 2, found: ${LAMBDA_COUNT})"
fi

echo ""
echo "=================================="
if [ "$FAILED" = true ]; then
    echo -e "${RED}Validation FAILED${NC}"
    echo "Please review errors above"
    exit 1
else
    echo -e "${GREEN}Validation PASSED${NC}"
    echo "All infrastructure components are operational"
    exit 0
fi
