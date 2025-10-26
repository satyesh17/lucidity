#!/bin/bash

echo "=============================================="
echo "🔍 DISK MONITORING SETUP VERIFICATION"
echo "=============================================="

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

MANAGEMENT_ACCOUNT="741752824171"
DEV_ACCOUNT="193779369106"
EXTERNAL_ID="DiskMonitoring-CrossAccount-12345"

echo ""
echo "1. Checking AWS CLI and credentials..."
if aws sts get-caller-identity > /dev/null 2>&1; then
    echo -e "${GREEN}✅ AWS CLI working${NC}"
    CURRENT_IDENTITY=$(aws sts get-caller-identity --query 'Arn' --output text)
    echo "   Current identity: $CURRENT_IDENTITY"
    
    # Check if we're using the management role
    if [[ "$CURRENT_IDENTITY" == *"DiskMonitoringManagementRole"* ]]; then
        echo -e "${GREEN}✅ Management account role is active${NC}"
    else
        echo -e "${YELLOW}⚠️  Not using management role, but credentials are working${NC}"
    fi
else
    echo -e "${RED}❌ AWS CLI not working${NC}"
    exit 1
fi

echo ""
echo "2. Testing EC2 permissions..."
if aws ec2 describe-instances --region us-east-1 --max-items 1 > /dev/null 2>&1; then
    echo -e "${GREEN}✅ EC2 describe permissions working${NC}"
    MGMT_INSTANCES=$(aws ec2 describe-instances --region us-east-1 --query 'Reservations[].Instances[?State.Name==`running`].[InstanceId]' --output text | wc -l)
    echo "   Management account instances: $MGMT_INSTANCES"
else
    echo -e "${RED}❌ EC2 permissions not working${NC}"
fi

echo ""
echo "3. Testing CloudWatch permissions..."
if aws cloudwatch list-metrics --namespace AWS/EC2 --max-records 1 > /dev/null 2>&1; then
    echo -e "${GREEN}✅ CloudWatch permissions working${NC}"
else
    echo -e "${RED}❌ CloudWatch permissions not working${NC}"
fi

echo ""
echo "4. Testing cross-account access..."
if aws sts assume-role \
    --role-arn "arn:aws:iam::${DEV_ACCOUNT}:role/DiskMonitoringCrossAccountRole" \
    --role-session-name "verification-test" \
    --external-id "${EXTERNAL_ID}" > /dev/null 2>&1; then
    echo -e "${GREEN}✅ Cross-account role assumption works${NC}"
    
    # Test dev account access
    DEV_CREDS=$(aws sts assume-role \
        --role-arn "arn:aws:iam::${DEV_ACCOUNT}:role/DiskMonitoringCrossAccountRole" \
        --role-session-name "verification-test" \
        --external-id "${EXTERNAL_ID}" 2>/dev/null)
    
    if [ $? -eq 0 ]; then
        ACCESS_KEY=$(echo $DEV_CREDS | jq -r '.Credentials.AccessKeyId')
        SECRET_KEY=$(echo $DEV_CREDS | jq -r '.Credentials.SecretAccessKey')
        SESSION_TOKEN=$(echo $DEV_CREDS | jq -r '.Credentials.SessionToken')
        
        DEV_INSTANCES=$(AWS_ACCESS_KEY_ID=$ACCESS_KEY AWS_SECRET_ACCESS_KEY=$SECRET_KEY AWS_SESSION_TOKEN=$SESSION_TOKEN \
            aws ec2 describe-instances --region us-east-1 --query 'Reservations[].Instances[?State.Name==`running`].[InstanceId]' --output text 2>/dev/null | wc -l)
        echo "   Dev account instances: $DEV_INSTANCES"
    fi
else
    echo -e "${RED}❌ Cross-account role assumption failed${NC}"
    echo "   Check:"
    echo "   - Role exists in dev account: ${DEV_ACCOUNT}"
    echo "   - External ID matches: ${EXTERNAL_ID}"
    echo "   - Trust relationship allows: ${MANAGEMENT_ACCOUNT}"
fi

echo ""
echo "5. Checking DynamoDB table..."
if aws dynamodb describe-table --table-name DiskMonitoringInventory > /dev/null 2>&1; then
    echo -e "${GREEN}✅ DynamoDB table exists${NC}"
else
    echo -e "${YELLOW}⚠️  DynamoDB table missing (will be created during deployment)${NC}"
fi

echo ""
echo "6. Checking S3 bucket..."
BUCKET_NAME="disk-monitoring-config-${MANAGEMENT_ACCOUNT}"
if aws s3 ls "s3://${BUCKET_NAME}" > /dev/null 2>&1; then
    echo -e "${GREEN}✅ S3 bucket exists${NC}"
else
    echo -e "${YELLOW}⚠️  S3 bucket missing (will be created during deployment)${NC}"
fi

echo ""
echo "7. Checking Ansible setup..."
if command -v ansible > /dev/null 2>&1; then
    echo -e "${GREEN}✅ Ansible installed${NC}"
    ansible --version | head -1
else
    echo -e "${RED}❌ Ansible not installed${NC}"
fi

if ansible-galaxy collection list | grep -q amazon.aws; then
    echo -e "${GREEN}✅ AWS Ansible collection installed${NC}"
else
    echo -e "${RED}❌ AWS Ansible collection missing${NC}"
    echo "   Run: ansible-galaxy collection install amazon.aws community.aws"
fi

echo ""
echo "8. Testing core permissions needed for deployment..."

# Test CloudWatch dashboard permissions
if aws cloudwatch put-dashboard --dashboard-name "test-dashboard" --dashboard-body '{"widgets":[]}' > /dev/null 2>&1; then
    echo -e "${GREEN}✅ CloudWatch dashboard permissions working${NC}"
    aws cloudwatch delete-dashboards --dashboard-names "test-dashboard" > /dev/null 2>&1
else
    echo -e "${YELLOW}⚠️  CloudWatch dashboard permissions may be limited${NC}"
fi

# Test DynamoDB permissions
if aws dynamodb list-tables > /dev/null 2>&1; then
    echo -e "${GREEN}✅ DynamoDB permissions working${NC}"
else
    echo -e "${RED}❌ DynamoDB permissions not working${NC}"
fi

echo ""
echo "=============================================="
echo "🏁 VERIFICATION COMPLETE"
echo "=============================================="

echo ""
echo "✅ = Ready to proceed"
echo "⚠️  = Will be handled during deployment"
echo "❌ = Needs to be fixed before deployment"

echo ""
echo "If most items show ✅, you can proceed with deployment:"
echo "ansible-playbook playbooks/00_full_deployment.yml -v"
