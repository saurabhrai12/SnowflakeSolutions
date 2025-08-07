#!/bin/bash
# Get public URL of an ECS service
# Usage: ./get-service-url.sh <cluster-name> <service-name> <port>

set -e

CLUSTER_NAME=$1
SERVICE_NAME=$2
PORT=$3

if [ -z "$CLUSTER_NAME" ] || [ -z "$SERVICE_NAME" ] || [ -z "$PORT" ]; then
    echo "Usage: $0 <cluster-name> <service-name> <port>"
    exit 1
fi

# Get the task ARN
TASK_ARN=$(aws ecs list-tasks \
    --cluster "$CLUSTER_NAME" \
    --service-name "$SERVICE_NAME" \
    --query 'taskArns[0]' \
    --output text 2>/dev/null)

if [ "$TASK_ARN" = "None" ] || [ -z "$TASK_ARN" ]; then
    echo "❌ No running tasks found for service $SERVICE_NAME"
    exit 1
fi

# Get the network interface ID
NETWORK_INTERFACE_ID=$(aws ecs describe-tasks \
    --cluster "$CLUSTER_NAME" \
    --tasks "$TASK_ARN" \
    --query 'tasks[0].attachments[0].details[?name==`networkInterfaceId`].value' \
    --output text 2>/dev/null)

if [ -z "$NETWORK_INTERFACE_ID" ]; then
    echo "❌ Could not find network interface for task"
    exit 1
fi

# Get the public IP
PUBLIC_IP=$(aws ec2 describe-network-interfaces \
    --network-interface-ids "$NETWORK_INTERFACE_ID" \
    --query 'NetworkInterfaces[0].Association.PublicIp' \
    --output text 2>/dev/null)

if [ "$PUBLIC_IP" = "None" ] || [ -z "$PUBLIC_IP" ]; then
    echo "❌ No public IP found for service $SERVICE_NAME"
    exit 1
fi

# Output the URL
echo "✅ http://$PUBLIC_IP:$PORT"

# Test if the service is responding
if command -v curl >/dev/null 2>&1; then
    if curl -s --max-time 5 "http://$PUBLIC_IP:$PORT" >/dev/null; then
        echo "🟢 Service is responding"
    else
        echo "🔴 Service is not responding (may still be starting up)"
    fi
fi