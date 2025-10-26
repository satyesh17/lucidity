#!/bin/bash

echo "🔄 Starting immediate metrics collection..."

cd /home/ec2-user/disk-monitoring-solution

# Run metrics collection
ansible-playbook playbooks/03_collect_metrics.yml -v

if [ $? -eq 0 ]; then
    echo ""
    echo "✅ Metrics collection completed!"
    echo ""
    echo "📊 View your dashboard:"
    echo "https://us-east-1.console.aws.amazon.com/cloudwatch/home?region=us-east-1#dashboards:name=DiskMonitoring-Dashboard"
    echo ""
    echo "📈 Check metrics in CloudWatch:"
    echo "Namespace: DiskMonitoring"
else
    echo "❌ Metrics collection failed. Check logs in logs/ansible.log"
fi
