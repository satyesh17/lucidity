#!/bin/bash

echo "🧹 CLEANUP SCRIPT - Disk Monitoring Solution"
echo "=============================================="

read -p "⚠️  This will remove all monitoring components. Are you sure? (yes/no): " confirm

if [ "$confirm" != "yes" ]; then
    echo "Cleanup cancelled."
    exit 0
fi

MANAGEMENT_ACCOUNT="741752824171"
DEV_ACCOUNT="193779369106"

echo ""
echo "1. Removing CloudWatch alarms..."
ALARMS=$(aws cloudwatch describe-alarms --alarm-name-prefix "DiskUsage-" --query 'MetricAlarms[].AlarmName' --output text)
for alarm in $ALARMS; do
    echo "   Deleting alarm: $alarm"
    aws cloudwatch delete-alarms --alarm-names "$alarm"
done

echo ""
echo "2. Removing CloudWatch dashboard..."
aws cloudwatch delete-dashboards --dashboard-names "DiskMonitoring-Dashboard"

echo ""
echo "3. Removing DynamoDB table..."
aws dynamodb delete-table --table-name DiskMonitoringInventory

echo ""
echo "4. Cleaning up S3 bucket..."
BUCKET_NAME="disk-monitoring-config-${MANAGEMENT_ACCOUNT}"
aws s3 rm "s3://${BUCKET_NAME}" --recursive
aws s3 rb "s3://${BUCKET_NAME}"

echo ""
echo "5. Note: IAM roles are NOT automatically deleted for safety."
echo "   To manually delete:"
echo "   - Management account: DiskMonitoringManagementRole"
echo "   - Dev account: DiskMonitoringCrossAccountRole"

echo ""
echo "✅ Cleanup completed!"
