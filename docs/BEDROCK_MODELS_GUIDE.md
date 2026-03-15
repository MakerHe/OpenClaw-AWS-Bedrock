# Bedrock Model Configuration Guide for OpenClaw

**Last Updated:** 2026-03-15  
**Region:** ap-northeast-1 (Tokyo)  
**Environment:** openclaw-test1

---

## 📊 Available Models Overview

Based on `aws bedrock list-foundation-models` in ap-northeast-1:

### Claude 4 Series (Latest - Requires Inference Profiles)

| Model | OpenClaw Config | Status | Use Case |
|-------|----------------|--------|----------|
| **Claude Sonnet 4.6** | `amazon-bedrock/global.anthropic.claude-sonnet-4-6` | ✅ | Best overall (recommended) |
| **Claude Opus 4.6** | `amazon-bedrock/global.anthropic.claude-opus-4-6-v1` | ✅ | Highest quality, expensive |
| **Claude Sonnet 4.5** | `amazon-bedrock/global.anthropic.claude-sonnet-4-5-20250929-v1:0` | ✅ | Proven stable |
| **Claude Haiku 4.5** | `amazon-bedrock/global.anthropic.claude-haiku-4-5-20251001-v1:0` | ✅ | Fast & cheap |

### Claude 3.5 Series (Stable)

| Model | OpenClaw Config | Status | Use Case |
|-------|----------------|--------|----------|
| **Claude 3.5 Sonnet (v2)** | `amazon-bedrock/anthropic.claude-3-5-sonnet-20241022-v2:0` | ✅ | Excellent balance |
| **Claude 3.5 Sonnet (v1)** | `amazon-bedrock/anthropic.claude-3-5-sonnet-20240620-v1:0` | ✅ | Previous version |

### Claude 3 Series (Budget-Friendly)

| Model | OpenClaw Config | Status | Use Case |
|-------|----------------|--------|----------|
| **Claude 3 Haiku** | `amazon-bedrock/anthropic.claude-3-haiku-20240307-v1:0` | ✅ | Fast, cheap |
| **Claude 3 Sonnet** | `amazon-bedrock/anthropic.claude-3-sonnet-20240229-v1:0` | ✅ | Mid-tier |

### Amazon Nova Series (Cost-Optimized)

| Model | OpenClaw Config | Status | Use Case |
|-------|----------------|--------|----------|
| **Nova 2 Lite** | `amazon-bedrock/global.amazon.nova-2-lite-v1:0` | ✅ | Ultra-cheap |
| **Nova 2 Sonic** | `amazon-bedrock/global.amazon.nova-2-sonic-v1:0` | ✅ | Fast & cheap |
| **Nova Lite v1** | `amazon-bedrock/amazon.nova-lite-v1:0` | ✅ | Budget option |
| **Nova Micro v1** | `amazon-bedrock/amazon.nova-micro-v1:0` | ✅ | Minimal cost |
| **Nova Sonic v1** | `amazon-bedrock/amazon.nova-sonic-v1:0` | ✅ | Speed focus |
| **Nova Pro v1** | `amazon-bedrock/amazon.nova-pro-v1:0` | ✅ | Balanced |

---

## 🎯 Quick Configuration

### Recommended Starting Point

```bash
# Best overall performance/cost balance
openclaw config set model 'amazon-bedrock/global.anthropic.claude-sonnet-4-5-20250929-v1:0'
```

### Alternative Options

**For highest quality (expensive):**
```bash
openclaw config set model 'amazon-bedrock/global.anthropic.claude-opus-4-6-v1'
```

**For speed & savings:**
```bash
openclaw config set model 'amazon-bedrock/anthropic.claude-3-haiku-20240307-v1:0'
```

**For ultra-low cost:**
```bash
openclaw config set model 'amazon-bedrock/global.amazon.nova-2-lite-v1:0'
```

---

## 📝 Configuration Methods

### Method 1: Via OpenClaw CLI (Recommended)

**On the instance (via SSM):**
```bash
# Connect to instance
aws ssm start-session --target i-02d0e970eac68c87c --region ap-northeast-1

# Configure model
openclaw config set model 'amazon-bedrock/MODEL_ID'

# Verify
openclaw config get model

# Check status
openclaw status | grep -A 3 "default"
```

### Method 2: Via SSM Remote Command

**From your local machine:**
```bash
COMMAND_ID=$(aws ssm send-command \
  --instance-ids i-02d0e970eac68c87c \
  --region ap-northeast-1 \
  --document-name "AWS-RunShellScript" \
  --parameters 'commands=["openclaw config set model amazon-bedrock/MODEL_ID"]' \
  --output text --query 'Command.CommandId')

# Wait and check result
sleep 5
aws ssm get-command-invocation \
  --command-id $COMMAND_ID \
  --instance-id i-02d0e970eac68c87c \
  --region ap-northeast-1 \
  --query 'StandardOutputContent' \
  --output text
```

### Method 3: Edit Config File Directly

```bash
# Edit ~/.openclaw/openclaw.json (root or ubuntu user depending on setup)
nano ~/.openclaw/openclaw.json

# Find and update:
{
  "model": "amazon-bedrock/MODEL_ID",
  ...
}

# Restart gateway (changes auto-reload but restart ensures clean state)
pkill -f openclaw-gateway
# Gateway will auto-restart if systemd managed
```

---

## 💰 Cost Comparison

### Pricing Tiers (Approximate, per 1M tokens)

| Tier | Models | Input | Output | Monthly (~10M tokens) |
|------|--------|-------|--------|-----------------------|
| **Premium** | Opus 4.6 | $15 | $75 | ~$900 |
| **Balanced** | Sonnet 4.5/4.6 | $3 | $15 | ~$180 |
| **Mid-Tier** | Claude 3.5 Sonnet | $3 | $15 | ~$180 |
| **Economy** | Haiku 3/4.5 | $0.25-0.80 | $1.25-4 | ~$25-50 |
| **Budget** | Nova Pro/Sonic | $0.50 | $2 | ~$25 |
| **Ultra-Low** | Nova Lite/Micro | $0.06-0.10 | $0.24-0.40 | ~$3-6 |

*Prices vary by region and are subject to change. Check AWS Bedrock pricing for latest.*

---

## 🚀 Model Selection Guide

### By Use Case

**General Purpose (Recommended):**
- Start with: `global.anthropic.claude-sonnet-4-5-20250929-v1:0`
- Fallback: `anthropic.claude-3-5-sonnet-20241022-v2:0`

**Complex Reasoning & Coding:**
- `global.anthropic.claude-opus-4-6-v1` (best quality)
- `global.anthropic.claude-sonnet-4-6` (good balance)

**Fast Responses (Chat, Simple Tasks):**
- `anthropic.claude-3-haiku-20240307-v1:0` (proven)
- `global.amazon.nova-2-sonic-v1:0` (AWS native, fast)

**Cost Optimization:**
- `global.amazon.nova-2-lite-v1:0` (cheapest)
- `amazon.nova-micro-v1:0` (minimal cost)

**Production (Stable & Proven):**
- `anthropic.claude-3-5-sonnet-20241022-v2:0`
- `anthropic.claude-3-haiku-20240307-v1:0`

### Performance Characteristics

| Metric | Opus 4.6 | Sonnet 4.5 | Haiku 3 | Nova Lite |
|--------|----------|------------|---------|-----------|
| **Quality** | ⭐⭐⭐⭐⭐ | ⭐⭐⭐⭐ | ⭐⭐⭐ | ⭐⭐ |
| **Speed** | ⭐⭐ | ⭐⭐⭐ | ⭐⭐⭐⭐⭐ | ⭐⭐⭐⭐⭐ |
| **Cost** | 💰💰💰💰💰 | 💰💰💰 | 💰💰 | 💰 |
| **Context** | 200K | 200K | 200K | 100K |

---

## ⚙️ Advanced Configuration

### Set Model with Additional Options

```bash
# Set model and adjust max tokens
openclaw config set model 'amazon-bedrock/MODEL_ID'
openclaw config set maxTokens 4096

# Set temperature (creativity)
openclaw config set temperature 0.7  # 0.0-1.0

# Check all model-related settings
openclaw config get | grep -i model
```

### Use Different Models for Different Sessions

OpenClaw supports per-session model override (advanced usage):

```javascript
// In custom scripts or skills
const session = await openclaw.sessions.create({
  model: 'amazon-bedrock/anthropic.claude-3-haiku-20240307-v1:0'
});
```

### Model Fallback Strategy

For production, consider a fallback:

```bash
# Primary model
openclaw config set model 'amazon-bedrock/global.anthropic.claude-sonnet-4-5-20250929-v1:0'

# If primary fails, OpenClaw can fall back to cheaper models
# Configure in openclaw.json:
{
  "model": "amazon-bedrock/global.anthropic.claude-sonnet-4-5-20250929-v1:0",
  "modelFallbacks": [
    "amazon-bedrock/anthropic.claude-3-5-sonnet-20241022-v2:0",
    "amazon-bedrock/anthropic.claude-3-haiku-20240307-v1:0"
  ]
}
```

---

## 🔧 Troubleshooting

### AccessDeniedException

**Error:** `AccessDeniedException: Could not resolve the foundation model from the model identifier`

**Fix:**
1. Open [Bedrock Console](https://ap-northeast-1.console.aws.amazon.com/bedrock/home?region=ap-northeast-1#/modelaccess)
2. Click "Edit" → Select models → Save
3. Wait 2-3 minutes for propagation
4. Retry

### Model Not Found

**Error:** `ValidationException: The provided model identifier is invalid`

**Fix:**
- Check model ID spelling (case-sensitive)
- Verify model available in ap-northeast-1
- Use `aws bedrock list-foundation-models --region ap-northeast-1`

### Inference Profile Required

**Error:** `Invocation of model ID ... with on-demand throughput isn't supported`

**Fix:**
- Use global inference profile: `global.MODEL_ID`
- Example: `global.anthropic.claude-sonnet-4-6` instead of `anthropic.claude-sonnet-4-6`

### Configuration Not Applied

**Fix:**
```bash
# Verify config
openclaw config get model

# Restart gateway
pkill -f openclaw-gateway
sleep 2
ps aux | grep openclaw-gateway

# Check logs
openclaw logs --follow | grep -i model
```

---

## 📊 Monitoring & Optimization

### Check Model Usage

```bash
# View current sessions and models
openclaw status | grep -A 5 "Sessions"

# Check CloudWatch metrics
aws cloudwatch get-metric-statistics \
  --namespace AWS/Bedrock \
  --metric-name Invocations \
  --dimensions Name=ModelId,Value=MODEL_ID \
  --start-time $(date -u -d '1 hour ago' +%Y-%m-%dT%H:%M:%S) \
  --end-time $(date -u +%Y-%m-%dT%H:%M:%S) \
  --period 3600 \
  --statistics Sum \
  --region ap-northeast-1
```

### Cost Monitoring

```bash
# Set up billing alarm (one-time)
aws cloudwatch put-metric-alarm \
  --alarm-name bedrock-high-cost \
  --alarm-description "Alert when Bedrock costs exceed $50" \
  --metric-name EstimatedCharges \
  --namespace AWS/Billing \
  --statistic Maximum \
  --period 86400 \
  --evaluation-periods 1 \
  --threshold 50 \
  --comparison-operator GreaterThanThreshold \
  --dimensions Name=ServiceName,Value=AmazonBedrock
```

---

## 🎓 Best Practices

1. **Start Conservative:** Begin with Sonnet 4.5, adjust based on needs
2. **Monitor Costs:** Set billing alarms, check usage weekly
3. **Test in Test Environment:** Use openclaw-test1 before changing production
4. **Enable Models First:** Always enable in Console before configuring
5. **Use Appropriate Models:** Don't use Opus for simple tasks
6. **Consider Latency:** Haiku/Nova for real-time chat, Sonnet for quality
7. **Regional Availability:** Some models only in specific regions
8. **Context Window:** Match model to your typical message length
9. **Batch Similar Tasks:** Use same model for related queries
10. **Review Periodically:** New models released, update quarterly

---

## 📚 Additional Resources

- [AWS Bedrock Models](https://docs.aws.amazon.com/bedrock/latest/userguide/models-supported.html)
- [OpenClaw Documentation](https://docs.openclaw.ai)
- [Bedrock Pricing](https://aws.amazon.com/bedrock/pricing/)
- [Model Access Management](https://docs.aws.amazon.com/bedrock/latest/userguide/model-access.html)

---

## 🔄 Quick Reference Commands

```bash
# List available models
aws bedrock list-foundation-models --region ap-northeast-1 --query 'modelSummaries[?modelLifecycle.status==`ACTIVE`].modelId' --output text

# Configure model
openclaw config set model 'amazon-bedrock/MODEL_ID'

# Verify
openclaw config get model

# Test with a message
openclaw chat "Hello, test message"

# Check status
openclaw status

# View logs
openclaw logs --follow

# Restart gateway
pkill -f openclaw-gateway
```

---

**For openclaw-test1 specifically:**
- Instance ID: `i-02d0e970eac68c87c`
- Region: `ap-northeast-1`
- Current Model: Check with `openclaw config get model`
- Access via SSM: `aws ssm start-session --target i-02d0e970eac68c87c --region ap-northeast-1`
