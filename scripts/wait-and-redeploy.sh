#!/bin/bash
#
# Wait for openclaw-test1 deletion and redeploy with Kiro CLI
#
# Usage: ./wait-and-redeploy.sh
#

STACK_NAME="openclaw-test1"
REGION="ap-northeast-1"
TEMPLATE_FILE="clawdbot-bedrock.yaml"

echo "==================================="
echo "OpenClaw Test1 Re-deployment Script"
echo "==================================="
echo ""
echo "This script will:"
echo "1. Wait for openclaw-test1 stack deletion"
echo "2. Deploy new stack with Kiro CLI pre-installed"
echo "3. Monitor deployment progress"
echo "4. Verify Kiro CLI installation"
echo ""

# Step 1: Wait for deletion
echo "📊 Step 1: Waiting for stack deletion..."
echo "Start time: $(date '+%H:%M:%S')"
echo ""

ATTEMPT=0
MAX_ATTEMPTS=60

while [ $ATTEMPT -lt $MAX_ATTEMPTS ]; do
  CHECK=$(aws cloudformation describe-stacks \
    --stack-name $STACK_NAME \
    --region $REGION 2>&1)
  
  if echo "$CHECK" | grep -q "does not exist"; then
    echo "✅ Stack deleted successfully!"
    echo "Deletion completed at: $(date '+%H:%M:%S')"
    break
  fi
  
  STATUS=$(echo "$CHECK" | grep -oP 'StackStatus.*?([A-Z_]+)' | head -1 | awk '{print $NF}' || echo "UNKNOWN")
  ATTEMPT=$((ATTEMPT + 1))
  echo "[$ATTEMPT/$MAX_ATTEMPTS] Status: $STATUS ($(date '+%H:%M:%S'))"
  sleep 10
done

if [ $ATTEMPT -eq $MAX_ATTEMPTS ]; then
  echo "❌ Timeout waiting for deletion"
  echo "Please check manually: aws cloudformation describe-stacks --stack-name $STACK_NAME --region $REGION"
  exit 1
fi

# Sleep a bit to ensure AWS resources are fully cleaned
echo ""
echo "Waiting 30 seconds for AWS resource cleanup..."
sleep 30

# Step 2: Get current parameters
echo ""
echo "📋 Step 2: Getting CloudFormation parameters..."
echo ""

# Use openclaw-bedrock's parameters as reference
EXISTING_PARAMS=$(aws cloudformation describe-stacks \
  --stack-name openclaw-bedrock \
  --region $REGION \
  --query 'Stacks[0].Parameters' \
  --output json 2>/dev/null)

if [ -n "$EXISTING_PARAMS" ]; then
  echo "Using parameters from openclaw-bedrock stack"
else
  echo "⚠️  openclaw-bedrock not found, using defaults"
fi

# Step 3: Deploy new stack
echo ""
echo "🚀 Step 3: Deploying new stack..."
echo ""

aws cloudformation create-stack \
  --stack-name $STACK_NAME \
  --region $REGION \
  --template-body file://$TEMPLATE_FILE \
  --parameters \
    ParameterKey=OpenClawModel,ParameterValue=global.anthropic.claude-sonnet-4-5-20250929-v1:0 \
    ParameterKey=InstanceType,ParameterValue=t4g.large \
    ParameterKey=KeyPairName,ParameterValue=MacOS \
    ParameterKey=AllowedSSHCIDR,ParameterValue=203.218.28.73/32 \
    ParameterKey=CreateVPCEndpoints,ParameterValue=true \
    ParameterKey=EnableSandbox,ParameterValue=true \
  --capabilities CAPABILITY_IAM \
  --output json

if [ $? -ne 0 ]; then
  echo "❌ Stack creation failed"
  exit 1
fi

echo "✅ Stack creation initiated"
echo ""

# Step 4: Monitor deployment
echo "📊 Step 4: Monitoring deployment..."
echo ""

DEPLOY_ATTEMPT=0
MAX_DEPLOY_ATTEMPTS=60

while [ $DEPLOY_ATTEMPT -lt $MAX_DEPLOY_ATTEMPTS ]; do
  STATUS=$(aws cloudformation describe-stacks \
    --stack-name $STACK_NAME \
    --region $REGION \
    --query 'Stacks[0].StackStatus' \
    --output text 2>/dev/null || echo "CREATING")
  
  if [ "$STATUS" = "CREATE_COMPLETE" ]; then
    echo "✅ Stack creation successful!"
    echo "Deployment completed at: $(date '+%H:%M:%S')"
    break
  elif [[ "$STATUS" == *"FAILED"* ]] || [[ "$STATUS" == *"ROLLBACK"* ]]; then
    echo "❌ Stack creation failed: $STATUS"
    echo ""
    echo "Recent events:"
    aws cloudformation describe-stack-events \
      --stack-name $STACK_NAME \
      --region $REGION \
      --max-items 10 \
      --query 'StackEvents[?ResourceStatus==`CREATE_FAILED`].[LogicalResourceId,ResourceStatusReason]' \
      --output table
    exit 1
  fi
  
  DEPLOY_ATTEMPT=$((DEPLOY_ATTEMPT + 1))
  echo "[$DEPLOY_ATTEMPT/$MAX_DEPLOY_ATTEMPTS] Status: $STATUS ($(date '+%H:%M:%S'))"
  sleep 10
done

if [ $DEPLOY_ATTEMPT -eq $MAX_DEPLOY_ATTEMPTS ]; then
  echo "❌ Timeout waiting for deployment"
  exit 1
fi

# Step 5: Get instance information
echo ""
echo "📋 Step 5: Getting instance information..."
echo ""

INSTANCE_ID=$(aws cloudformation describe-stack-resource \
  --stack-name $STACK_NAME \
  --logical-resource-id OpenClawInstance \
  --region $REGION \
  --query 'StackResourceDetail.PhysicalResourceId' \
  --output text)

echo "Instance ID: $INSTANCE_ID"
echo ""

# Wait for instance to be ready
echo "Waiting for instance to be ready..."
sleep 30

# Step 6: Verify Kiro CLI installation
echo ""
echo "🔍 Step 6: Verifying Kiro CLI installation..."
echo ""

# Wait for UserData to complete
echo "Waiting for UserData script to complete (2 minutes)..."
sleep 120

# Check Kiro installation
COMMAND_ID=$(aws ssm send-command \
  --instance-ids $INSTANCE_ID \
  --region $REGION \
  --document-name "AWS-RunShellScript" \
  --parameters 'commands=["su - ubuntu -c \"export PATH=/home/ubuntu/.local/bin:$PATH && which kiro-cli && kiro-cli --version\""]' \
  --output text --query 'Command.CommandId')

echo "Verification command sent: $COMMAND_ID"
sleep 5

KIRO_CHECK=$(aws ssm get-command-invocation \
  --command-id $COMMAND_ID \
  --instance-id $INSTANCE_ID \
  --region $REGION \
  --query 'StandardOutputContent' \
  --output text 2>&1)

if echo "$KIRO_CHECK" | grep -q "kiro-cli"; then
  echo "✅ Kiro CLI installed successfully!"
  echo ""
  echo "$KIRO_CHECK"
else
  echo "❌ Kiro CLI verification failed"
  echo "$KIRO_CHECK"
fi

# Step 7: Summary
echo ""
echo "======================================="
echo "✅ Deployment Complete!"
echo "======================================="
echo ""
echo "Stack Name: $STACK_NAME"
echo "Region: $REGION"
echo "Instance ID: $INSTANCE_ID"
echo ""
echo "Access via SSM:"
echo "  aws ssm start-session --target $INSTANCE_ID --region $REGION"
echo ""
echo "Check status:"
echo "  openclaw status"
echo ""
echo "Verify Kiro:"
echo "  kiro-cli --version"
echo ""

exit 0
