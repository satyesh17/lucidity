#!/bin/bash
echo "🚀 Starting Disk Monitoring Solution Deployment"
echo "=============================================="
cd /home/ec2-user/disk-monitoring-solution

echo "Step 1: Discovering EC2 instances..."
ansible-playbook playbooks/01_discover_instances.yml -v
if [ $? -ne 0 ]; then echo "❌ Instance discovery failed!"; exit 1; fi

echo "Step 2: Installing CloudWatch Agents..."
ansible-playbook playbooks/02_install_agents.yml -v
if [ $? -ne 0 ]; then echo "❌ Agent installation failed!"; exit 1; fi

echo "Step 3: Collecting metrics..."
ansible-playbook playbooks/03_collect_metrics.yml -v
if [ $? -ne 0 ]; then echo "❌ Metrics collection failed!"; exit 1; fi

echo "Step 4: Creating dashboard..."
ansible-playbook playbooks/04_create_dashboard.yml -v
if [ $? -ne 0 ]; then echo "❌ Dashboard creation failed!"; exit 1; fi

echo "🎉 DEPLOYMENT COMPLETED SUCCESSFULLY!"
echo "📊 Dashboard: https://us-east-1.console.aws.amazon.com/cloudwatch/home?region=us-east-1#dashboards:name=DiskMonitoring-Dashboard"
