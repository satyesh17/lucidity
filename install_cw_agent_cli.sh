#!/bin/bash

echo "🔧 Installing CloudWatch Agent via AWS CLI"
echo "==========================================="

# Function to send SSM command
send_ssm_command() {
    local INSTANCE_ID=$1
    local ACCOUNT_TYPE=$2
    local AWS_CREDS=$3
    
    echo "Installing CloudWatch Agent on $INSTANCE_ID ($ACCOUNT_TYPE account)..."
    
    # Create the installation script
    INSTALL_SCRIPT='#!/bin/bash
echo "Starting CloudWatch Agent installation..."
cd /tmp

# Download CloudWatch Agent
echo "Downloading CloudWatch Agent..."
wget -q https://s3.amazonaws.com/amazoncloudwatch-agent/amazon_linux/amd64/latest/amazon-cloudwatch-agent.rpm || {
    curl -O https://s3.amazonaws.com/amazoncloudwatch-agent/amazon_linux/amd64/latest/amazon-cloudwatch-agent.rpm
}

# Install the agent
echo "Installing CloudWatch Agent..."
sudo rpm -U ./amazon-cloudwatch-agent.rpm 2>/dev/null || sudo yum install -y ./amazon-cloudwatch-agent.rpm

# Create config directory
sudo mkdir -p /opt/aws/amazon-cloudwatch-agent/etc

# Create configuration file
echo "Creating CloudWatch Agent configuration..."
sudo tee /opt/aws/amazon-cloudwatch-agent/etc/amazon-cloudwatch-agent.json > /dev/null << '"'"'EOFCONFIG'"'"'
{
  "agent": {
    "metrics_collection_interval": 60,
    "run_as_user": "cwagent"
  },
  "metrics": {
    "namespace": "DiskMonitoring",
    "metrics_collected": {
      "disk": {
        "measurement": [
          "used_percent",
          "free",
          "used",
          "total"
        ],
        "metrics_collection_interval": 60,
        "resources": ["*"],
        "totalDisk": true,
        "ignore_file_system_types": ["tmpfs", "devtmpfs", "sysfs"]
      },
      "diskio": {
        "measurement": [
          "io_time",
          "reads", 
          "writes",
          "read_bytes",
          "write_bytes"
        ],
        "metrics_collection_interval": 60,
        "resources": ["*"]
      }
    },
    "append_dimensions": {
      "InstanceId": "${aws:InstanceId}",
      "InstanceType": "${aws:InstanceType}",
      "AccountType": "'"$ACCOUNT_TYPE"'"
    }
  }
}
EOFCONFIG

# Start the agent with configuration
echo "Starting CloudWatch Agent..."
sudo /opt/aws/amazon-cloudwatch-agent/bin/amazon-cloudwatch-agent-ctl \
  -a fetch-config -m ec2 -s \
  -c file:/opt/aws/amazon-cloudwatch-agent/etc/amazon-cloudwatch-agent.json

# Enable and start service
sudo systemctl enable amazon-cloudwatch-agent
sudo systemctl start amazon-cloudwatch-agent

# Check status
sleep 5
echo "CloudWatch Agent Status:"
sudo systemctl status amazon-cloudwatch-agent --no-pager

echo "CloudWatch Agent installation completed on $(hostname)"
'

    # Send the command via SSM
    if [ "$ACCOUNT_TYPE" = "dev" ]; then
        # Use dev account credentials
        eval $AWS_CREDS
    fi
    
    COMMAND_ID=$(aws ssm send-command \
        --instance-ids "$INSTANCE_ID" \
        --document-name "AWS-RunShellScript" \
        --parameters "commands=[\"$INSTALL_SCRIPT\"]" \
        --query 'Command.CommandId' \
        --output text \
        --region us-east-1)
    
    echo "Command ID: $COMMAND_ID"
    
    # Wait for command to complete
    echo "Waiting for installation to complete..."
    sleep 30
    
    # Get command result
    RESULT=$(aws ssm get-command-invocation \
        --command-id "$COMMAND_ID" \
        --instance-id "$INSTANCE_ID" \
        --query 'StandardOutputContent' \
        --output text \
        --region us-east-1 2>/dev/null)
    
    echo "Installation result for $INSTANCE_ID:"
    echo "$RESULT"
    echo "----------------------------------------"
}

# Get management account instances
echo "=== Installing on Management Account Instances ==="
aws ec2 describe-instances --region us-east-1 \
  --filters "Name=instance-state-name,Values=running" \
  --query 'Reservations[].Instances[].[InstanceId]' \
  --output text | while read INSTANCE_ID; do
  
  if [ ! -z "$INSTANCE_ID" ]; then
    send_ssm_command "$INSTANCE_ID" "management" ""
  fi
done

# Get dev account instances
echo "=== Installing on Dev Account Instances ==="
DEV_CREDS=$(aws sts assume-role \
  --role-arn "arn:aws:iam::193779369106:role/DiskMonitoringCrossAccountRole" \
  --role-session-name "install-cw-agent" \
  --external-id "DiskMonitoring-CrossAccount-12345" 2>/dev/null)

if [ $? -eq 0 ]; then
  ACCESS_KEY=$(echo $DEV_CREDS | jq -r '.Credentials.AccessKeyId')
  SECRET_KEY=$(echo $DEV_CREDS | jq -r '.Credentials.SecretAccessKey')
  SESSION_TOKEN=$(echo $DEV_CREDS | jq -r '.Credentials.SessionToken')
  
  DEV_AWS_CREDS="export AWS_ACCESS_KEY_ID=$ACCESS_KEY; export AWS_SECRET_ACCESS_KEY=$SECRET_KEY; export AWS_SESSION_TOKEN=$SESSION_TOKEN"
  
  eval $DEV_AWS_CREDS
  aws ec2 describe-instances --region us-east-1 \
    --filters "Name=instance-state-name,Values=running" \
    --query 'Reservations[].Instances[].[InstanceId]' \
    --output text | while read INSTANCE_ID; do
    
    if [ ! -z "$INSTANCE_ID" ]; then
      send_ssm_command "$INSTANCE_ID" "dev" "$DEV_AWS_CREDS"
    fi
  done
else
  echo "❌ Cannot access dev account"
fi

echo ""
echo "✅ CloudWatch Agent installation completed!"
echo ""
echo "Wait 5-10 minutes, then check for metrics:"
echo "aws cloudwatch list-metrics --namespace DiskMonitoring --output table"
