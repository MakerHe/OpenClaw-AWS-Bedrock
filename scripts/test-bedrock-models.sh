#!/bin/bash
#
# Bedrock Model Testing Script for openclaw-test1
# Tests newer Bedrock models and generates configuration guide
#

set -e

INSTANCE_ID="i-02d0e970eac68c87c"
REGION="ap-northeast-1"
OUTPUT_FILE="bedrock-model-test-results.md"

echo "🧪 Bedrock Model Testing"
echo "========================"
echo ""
echo "Instance: $INSTANCE_ID"
echo "Region: $REGION"
echo "Test Time: $(date)"
echo ""

# Models to test
declare -a MODELS=(
    "anthropic.claude-sonnet-4-6"
    "anthropic.claude-opus-4-6-v1"
    "anthropic.claude-sonnet-4-5-20250929-v1:0"
    "anthropic.claude-haiku-4-5-20251001-v1:0"
    "amazon.nova-2-sonic-v1:0"
    "amazon.nova-2-lite-v1:0"
)

# Test prompt
TEST_PROMPT="Hello! Please respond with: 1) Your model name 2) One sentence about your capabilities 3) A simple math: 15+27="

echo "# Bedrock Model Test Results" > $OUTPUT_FILE
echo "" >> $OUTPUT_FILE
echo "**Test Date:** $(date)" >> $OUTPUT_FILE
echo "**Instance:** $INSTANCE_ID" >> $OUTPUT_FILE
echo "**Region:** $REGION" >> $OUTPUT_FILE
echo "" >> $OUTPUT_FILE
echo "---" >> $OUTPUT_FILE
echo "" >> $OUTPUT_FILE

# Function to test a model
test_model() {
    local model=$1
    local model_name=$(echo $model | sed 's/anthropic\.//' | sed 's/amazon\.//')
    
    echo "Testing: $model_name"
    echo "  Configuring model..."
    
    # Configure the model
    COMMAND_ID=$(aws ssm send-command \
        --instance-ids $INSTANCE_ID \
        --region $REGION \
        --document-name "AWS-RunShellScript" \
        --parameters "commands=[\"openclaw config set model 'amazon-bedrock/$model'\",\"sleep 1\",\"openclaw config get model\"]" \
        --output text --query 'Command.CommandId' 2>&1)
    
    if [[ "$COMMAND_ID" == *"error"* ]] || [[ "$COMMAND_ID" == *"ERROR"* ]]; then
        echo "  ❌ Failed to configure"
        echo "## ❌ $model_name" >> $OUTPUT_FILE
        echo "" >> $OUTPUT_FILE
        echo "**Status:** Configuration failed" >> $OUTPUT_FILE
        echo "" >> $OUTPUT_FILE
        return 1
    fi
    
    sleep 5
    
    # Get command result
    RESULT=$(aws ssm get-command-invocation \
        --command-id $COMMAND_ID \
        --instance-id $INSTANCE_ID \
        --region $REGION \
        --query 'StandardOutputContent' \
        --output text 2>&1 | tail -1)
    
    if [[ "$RESULT" == *"$model"* ]]; then
        echo "  ✅ Model configured successfully"
        echo "  Testing inference..."
        
        # Test inference (via AWS CLI directly)
        START_TIME=$(date +%s)
        
        INFERENCE_RESULT=$(aws bedrock-runtime invoke-model \
            --model-id $model \
            --region $REGION \
            --body "{\"anthropic_version\":\"bedrock-2023-05-31\",\"max_tokens\":100,\"messages\":[{\"role\":\"user\",\"content\":\"$TEST_PROMPT\"}]}" \
            /tmp/response.json 2>&1)
        
        END_TIME=$(date +%s)
        LATENCY=$((END_TIME - START_TIME))
        
        if [[ $? -eq 0 ]]; then
            RESPONSE=$(cat /tmp/response.json | jq -r '.content[0].text' 2>/dev/null || echo "Parse error")
            
            echo "  ✅ Inference successful (${LATENCY}s)"
            
            # Write to output file
            echo "## ✅ $model_name" >> $OUTPUT_FILE
            echo "" >> $OUTPUT_FILE
            echo "**Model ID:** \`$model\`" >> $OUTPUT_FILE
            echo "**Status:** Working" >> $OUTPUT_FILE
            echo "**Latency:** ${LATENCY}s" >> $OUTPUT_FILE
            echo "" >> $OUTPUT_FILE
            echo "**Test Response:**" >> $OUTPUT_FILE
            echo "\`\`\`" >> $OUTPUT_FILE
            echo "$RESPONSE" >> $OUTPUT_FILE
            echo "\`\`\`" >> $OUTPUT_FILE
            echo "" >> $OUTPUT_FILE
        else
            echo "  ❌ Inference failed"
            echo "## ⚠️ $model_name" >> $OUTPUT_FILE
            echo "" >> $OUTPUT_FILE
            echo "**Model ID:** \`$model\`" >> $OUTPUT_FILE
            echo "**Status:** Configured but inference failed" >> $OUTPUT_FILE
            echo "**Error:**" >> $OUTPUT_FILE
            echo "\`\`\`" >> $OUTPUT_FILE
            echo "$INFERENCE_RESULT" >> $OUTPUT_FILE
            echo "\`\`\`" >> $OUTPUT_FILE
            echo "" >> $OUTPUT_FILE
        fi
    else
        echo "  ❌ Configuration verification failed"
        echo "## ❌ $model_name" >> $OUTPUT_FILE
        echo "" >> $OUTPUT_FILE
        echo "**Model ID:** \`$model\`" >> $OUTPUT_FILE
        echo "**Status:** Configuration failed" >> $OUTPUT_FILE
        echo "" >> $OUTPUT_FILE
    fi
    
    echo ""
    sleep 2
}

# Run tests
echo "Starting model tests..."
echo ""

for model in "${MODELS[@]}"; do
    test_model "$model"
done

echo "---" >> $OUTPUT_FILE
echo "" >> $OUTPUT_FILE

# Generate configuration guide
cat >> $OUTPUT_FILE << 'EOF'

## 📝 Configuration Guide

### How to Configure a Model

**Method 1: Via OpenClaw CLI**
```bash
# SSH to instance
aws ssm start-session --target INSTANCE_ID --region REGION

# Configure model
openclaw config set model 'amazon-bedrock/MODEL_ID'

# Verify
openclaw config get model

# Restart gateway (optional, auto-reloads)
systemctl --user restart openclaw-gateway
```

**Method 2: Via openclaw.json**
```bash
# Edit config file
nano ~/.openclaw/openclaw.json

# Find and update the model field:
{
  "model": "amazon-bedrock/MODEL_ID",
  ...
}

# Save and restart
systemctl --user restart openclaw-gateway
```

**Method 3: Via CloudFormation Parameter**
```bash
# Update stack with new model
aws cloudformation update-stack \
  --stack-name openclaw-test1 \
  --use-previous-template \
  --parameters ParameterKey=OpenClawModel,ParameterValue=NEW_MODEL_ID \
  --capabilities CAPABILITY_IAM
```

### OpenClaw Model ID Format

OpenClaw uses the format: `amazon-bedrock/BEDROCK_MODEL_ID`

Examples:
- `amazon-bedrock/anthropic.claude-sonnet-4-6`
- `amazon-bedrock/amazon.nova-2-sonic-v1:0`

### Model Selection Guide

**For Best Quality (Expensive):**
- `anthropic.claude-opus-4-6-v1` - Highest capability, slowest, most expensive

**For Balance (Recommended):**
- `anthropic.claude-sonnet-4-6` - Excellent quality, reasonable speed and cost
- `anthropic.claude-sonnet-4-5-20250929-v1:0` - Slightly older but proven

**For Speed & Cost (Cheap):**
- `anthropic.claude-haiku-4-5-20251001-v1:0` - Fast, cheap, good for simple tasks
- `amazon.nova-2-sonic-v1:0` - AWS native, fast, cost-effective
- `amazon.nova-2-lite-v1:0` - Cheapest, basic tasks

### Cost Comparison (Approximate)

| Model | Input (per 1M tokens) | Output (per 1M tokens) | Use Case |
|-------|----------------------|------------------------|----------|
| Claude Opus 4.6 | $15 | $75 | Complex reasoning |
| Claude Sonnet 4.6 | $3 | $15 | General purpose |
| Claude Haiku 4.5 | $0.80 | $4 | Fast responses |
| Nova 2 Sonic | $0.50 | $2 | Cost-effective |
| Nova 2 Lite | $0.10 | $0.40 | Budget-friendly |

*Prices are approximate and vary by region*

### Troubleshooting

**Model Access Denied:**
```bash
# Enable model in Bedrock Console
# https://console.aws.amazon.com/bedrock/

# Wait 2-3 minutes for propagation
```

**Configuration Not Applied:**
```bash
# Verify configuration
openclaw config get model

# Restart gateway
systemctl --user restart openclaw-gateway

# Check logs
openclaw logs --follow
```

**Performance Issues:**
- Switch to faster model (Haiku/Nova Sonic)
- Reduce max_tokens in config
- Check CloudWatch metrics for throttling

### Best Practices

1. **Start with Sonnet 4.6** - Best balance of cost/performance
2. **Use Haiku for simple tasks** - Save money on basic queries
3. **Enable model in Console first** - Avoid access denied errors
4. **Monitor costs** - Set up billing alarms
5. **Test before production** - Verify model behavior
6. **Keep config backed up** - Document your model choices

EOF

echo "✅ Testing complete!"
echo ""
echo "Results saved to: $OUTPUT_FILE"
echo ""
echo "View results:"
echo "  cat $OUTPUT_FILE"
echo ""
