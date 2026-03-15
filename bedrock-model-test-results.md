# Bedrock Model Testing Summary - openclaw-test1

**Test Date:** 2026-03-15 04:40 UTC  
**Instance:** i-02d0e970eac68c87c (openclaw-test1)  
**Region:** ap-northeast-1 (Tokyo)  
**Tester:** OpenClaw AI Assistant

---

## ✅ Successfully Configured Model

**Model:** Claude Sonnet 4.5  
**Model ID:** `global.anthropic.claude-sonnet-4-5-20250929-v1:0`  
**Status:** ✅ Configured and ready  
**Configuration Command:**
```bash
openclaw config set model "amazon-bedrock/global.anthropic.claude-sonnet-4-5-20250929-v1:0"
```

---

## 📊 Available Models in ap-northeast-1

Total found: **20 ACTIVE models**

### By Family

**Claude 4 Series (6 models):**
- claude-sonnet-4-6
- claude-opus-4-6-v1
- claude-sonnet-4-5-20250929-v1:0
- claude-sonnet-4-20250514-v1:0
- claude-haiku-4-5-20251001-v1:0
- claude-opus-4-5-20251101-v1:0

**Claude 3.5 Series (2 models):**
- claude-3-5-sonnet-20241022-v2:0
- claude-3-5-sonnet-20240620-v1:0

**Claude 3 Series (4 models):**
- claude-3-haiku-20240307-v1:0
- claude-3-sonnet-20240229-v1:0 (with variants)
- claude-3-7-sonnet-20250219-v1:0 (LEGACY)

**Nova Series (6 models):**
- nova-2-lite-v1:0
- nova-2-sonic-v1:0
- nova-lite-v1:0
- nova-micro-v1:0
- nova-pro-v1:0
- nova-sonic-v1:0

**Nova Creative (2 models):**
- nova-canvas-v1:0 (image generation)
- nova-reel-v1:0 (video generation)

---

## 🎯 Recommended Models

### For General Use (Best Balance)
```bash
# Recommended starting point
openclaw config set model 'amazon-bedrock/global.anthropic.claude-sonnet-4-5-20250929-v1:0'
```

### For Cost Optimization
```bash
# Fast and cheap
openclaw config set model 'amazon-bedrock/anthropic.claude-3-haiku-20240307-v1:0'

# Ultra-low cost
openclaw config set model 'amazon-bedrock/global.amazon.nova-2-lite-v1:0'
```

### For Maximum Quality
```bash
# Best performance (expensive)
openclaw config set model 'amazon-bedrock/global.anthropic.claude-opus-4-6-v1'
```

---

## 💰 Cost Estimates

Based on AWS Bedrock pricing in ap-northeast-1:

| Tier | Example Model | Input/1M | Output/1M | 10M tokens/month |
|------|--------------|----------|-----------|------------------|
| **Premium** | Opus 4.6 | ~$15 | ~$75 | ~$900 |
| **Balanced** | Sonnet 4.5 | ~$3 | ~$15 | ~$180 |
| **Economy** | Haiku 3 | ~$0.25 | ~$1.25 | ~$25 |
| **Budget** | Nova Lite | ~$0.06 | ~$0.24 | ~$3 |

---

## 🔧 Configuration Status

### openclaw-test1 Current Setup

**Instance Details:**
- ID: i-02d0e970eac68c87c
- Type: t4g.large (Graviton ARM64)
- Private IP: 10.0.1.215
- Public IP: 18.179.120.202

**OpenClaw Status:**
- Gateway: ✅ Running (PID varies)
- Version: 2026.3.13 (latest)
- Model: ✅ Claude Sonnet 4.5 configured
- Channels: Not configured yet

**Access:**
- Web UI: http://localhost:18789 (via SSM port forwarding)
- Token: Available in SSM Parameter Store
- SSH: Via SSM Session Manager

---

## 📝 Testing Notes

### What Worked
- ✅ OpenClaw CLI configuration commands
- ✅ Model string format: `amazon-bedrock/MODEL_ID`
- ✅ Global inference profiles: `global.MODEL_ID`
- ✅ SSM remote commands for configuration

### Known Issues
- ⚠️ Direct AWS CLI invoke-model requires base64 encoding
- ⚠️ Some Claude 4 models require global inference profiles
- ⚠️ Models must be enabled in Bedrock Console first

### Not Tested
- Actual inference through OpenClaw (requires channel setup)
- Model switching performance
- Fallback behavior
- Cross-region availability

---

## 🚀 Next Steps

### For openclaw-test1

**1. Enable Required Models** (if not already)
- Open [Bedrock Console](https://ap-northeast-1.console.aws.amazon.com/bedrock/home?region=ap-northeast-1#/modelaccess)
- Enable: Claude Sonnet 4.5, Claude Haiku, Nova models
- Wait 2-3 minutes

**2. Configure Messaging Channel**
```bash
# Connect via SSM
aws ssm start-session --target i-02d0e970eac68c87c --region ap-northeast-1

# Access Web UI or configure Telegram via CLI
openclaw channel configure telegram
```

**3. Test Inference**
- Send a message via Telegram
- Verify Bedrock API call
- Check CloudWatch logs

**4. Monitor Costs**
```bash
# Set billing alarm
aws cloudwatch put-metric-alarm \
  --alarm-name openclaw-test1-bedrock-cost \
  --metric-name EstimatedCharges \
  --namespace AWS/Billing \
  --statistic Maximum \
  --period 86400 \
  --evaluation-periods 1 \
  --threshold 50 \
  --comparison-operator GreaterThanThreshold
```

---

## 📚 Documentation

**Full Guide:** `docs/BEDROCK_MODELS_GUIDE.md`
- 15+ models detailed
- Configuration methods
- Cost comparison
- Troubleshooting
- Best practices

**Test Script:** `scripts/test-bedrock-models.sh`
- Automated model testing
- Direct Bedrock API calls
- Result generation

---

## 🎓 Lessons Learned

1. **Use Global Profiles:** Newer Claude 4 models need `global.` prefix
2. **Enable in Console:** Always enable models before configuring
3. **Start Conservative:** Begin with Sonnet, scale up/down as needed
4. **Monitor Costs:** Opus can be 30x more expensive than Nova Lite
5. **Regional Variance:** Model availability varies by AWS region
6. **Test Before Production:** Use openclaw-test1 for validation

---

## ✅ Deployment Status

**openclaw-test1:** Ready for channel configuration and testing  
**Model Configuration:** ✅ Complete  
**Documentation:** ✅ Generated  
**Repository:** ✅ Updated and pushed

**Ready to proceed with Telegram/WhatsApp configuration or production testing.**

---

*For questions or issues, see `BEDROCK_MODELS_GUIDE.md` or `TROUBLESHOOTING.md`*
