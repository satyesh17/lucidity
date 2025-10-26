#!/bin/bash

echo "🔍 Checking CloudWatch Agent Status Across All Instances"
echo "========================================================"

cd /home/ec2-user/disk-monitoring-solution

# Check management account instances
echo "=== Management Account Instances ==="
aws ec2 describe-instances --region us-east-1 \
  --filters "Name=instance-state-name,Values=running" \
  --query 'Reservations[].Instances[].[InstanceId,Tags[?Key==`Name`].Value|[0]]' \
  --output text | while read INSTANCE_ID INSTANCE_NAME; do
  
  echo "Checking $INSTANCE_ID ($INSTANCE_NAME)..."
  
  # Check if SSM is available
  SSM_STATUS=$(aws ssm describe-instance-information \
    --filters "Name=InstanceIds,Values=$INSTANCE_ID" \
    --query 'InstanceInformationList[0].PingStatus' --output text 2>/dev/null)
  
  if [ "$SSM_STATUS" = "Online" ]; then
    echo "  ✅ SSM Online"
    
    # Check CloudWatch Agent status
    aws ssm send-command \
      --instance-ids "$INSTANCE_ID" \
      --document-name "AWS-RunShellScript" \
      --parameters 'commands=["sudo systemctl status amazon-cloudwatch-agent --no-pager"]' \
      --query 'Command.CommandId' --output text > /tmp/cmd_id_$INSTANCE_ID
    
    sleep 5
    
    CMD_ID=$(cat /tmp/cmd_id_$INSTANCE_ID)
    aws ssm get-command-invocation \
      --command-id "$CMD_ID" \
      --instance-id "$INSTANCE_ID" \
      --query 'StandardOutputContent' --output text
  else
    echo "  ❌ SSM Offline or not available"
  fi
  echo ""
done

# Check dev account instances
echo "=== Dev Account Instances ==="
DEV_CREDS=$(aws sts assume-role \
  --role-arn "arn:aws:iam::193779369106:role/DiskMonitoringCrossAccountRole" \
  --role-session-name "agent-check" \
  --external-id "DiskMonitoring-CrossAccount-12345" 2>/dev/null)

if [ $? -eq 0 ]; then
  ACCESS_KEY=$(echo $DEV_CREDS | jq -r '.Credentials.AccessKeyId')
  SECRET_KEY=$(echo $DEV_CREDS | jq -r '.Credentials.SecretAccessKey')
  SESSION_TOKEN=$(echo $DEV_CREDS | jq -r '.Credentials.SessionToken')
  
  AWS_ACCESS_KEY_ID=$ACCESS_KEY AWS_SECRET_ACCESS_KEY=$SECRET_KEY AWS_SESSION_TOKEN=$SESSION_TOKEN \
  aws ec2 describe-instances --region us-east-1 \
    --filters "Name=instance-state-name,Values=running" \
    --query 'Reservations[].Instances[].[InstanceId,Tags[?Key==`Name`].Value|[0]]' \
    --output text | while read INSTANCE_ID INSTANCE_NAME; do
    
    echo "Checking $INSTANCE_ID ($INSTANCE_NAME) in dev account..."
    
    # Check if SSM is available
    SSM_STATUS=$(AWS_ACCESS_KEY_ID=$ACCESS_KEY AWS_SECRET_ACCESS_KEY=$SECRET_KEY AWS_SESSION_TOKEN=$SESSION_TOKEN \
      aws ssm describe-instance-information \
      --filters "Name=InstanceIds,Values=$INSTANCE_ID" \
      --query 'InstanceInformationList[0].PingStatus' --output text 2>/dev/null)
    
    if [ "$SSM_STATUS" = "Online" ]; then
      echo "  ✅ SSM Online"
      
      # Check CloudWatch Agent status
      AWS_ACCESS_KEY_ID=$ACCESS_KEY AWS_SECRET_ACCESS_KEY=$SECRET_KEY AWS_SESSION_TOKEN=$SESSION_TOKEN \
      aws ssm send-command \
        --instance-ids "$INSTANCE_ID" \
        --document-name "AWS-RunShellScript" \
        --parameters 'commands=["sudo systemctl status amazon-cloudwatch-agent --no-pager"]' \
        --query 'Command.CommandId' --output text > /tmp/cmd_id_dev_$INSTANCE_ID
      
      sleep 5
      
      CMD_ID=$(cat /tmp/cmd_id_dev_$INSTANCE_ID)
      AWS_ACCESS_KEY_ID=$ACCESS_KEY AWS_SECRET_ACCESS_KEY=$SECRET_KEY AWS_SESSION_TOKEN=$SESSION_TOKEN \
      aws ssm get-command-invocation \
        --command-id "$CMD_ID" \
        --instance-id "$INSTANCE_ID" \
        --query 'StandardOutputContent' --output text
    else
      echo "  ❌ SSM Offline or not available"
    fi
    echo ""
  done
else
  echo "❌ Cannot access dev account"
fi
