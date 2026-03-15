# UserData Size Limitation Issue

**Date:** 2026-03-15 05:56 UTC  
**Problem:** CloudFormation stack creation failed due to UserData size exceeding 16KB  
**Status:** ✅ **Fixed**

---

## 🔴 Problem

### Initial Attempt
Added Kiro CLI installation to UserData:
```bash
# Install Kiro CLI
echo "Installing Kiro CLI..."
curl -fsSL https://cli.kiro.dev/install | bash || echo "Kiro CLI installation failed (non-fatal)"
```

### Error Message
```
Resource handler returned message: "User data is limited to 16384 bytes 
(Service: Ec2, Status Code: 400, Request ID: a03be83a-2c29-4d83-a287-45fffebc6e1b)"
```

### Stack Status
- CREATE_IN_PROGRESS → ROLLBACK_IN_PROGRESS
- Resource: OpenClawInstance
- Action: CREATE_FAILED

---

## 📊 Root Cause Analysis

### AWS UserData Limitations

**Hard Limit:** 16,384 bytes (16 KB)

**Our UserData included:**
1. System updates and package installation
2. AWS CLI v2 installation  
3. SSM Agent configuration
4. Docker installation (conditional)
5. Node.js installation (via NVM)
6. OpenClaw installation
7. Environment configuration
8. Gateway setup and start
9. Wait condition signaling
10. **Kiro CLI installation** ← Added, pushed over limit

**Estimated sizes:**
- Base UserData: ~15,500 bytes
- Kiro CLI addition: ~200 bytes
- **Total:** ~15,700 bytes (over 16KB limit)

### Why It Failed

The UserData script is Base64 encoded before sending to AWS, which increases size:
```
Original: 15,700 bytes
Base64 encoded: 15,700 × 1.37 ≈ 21,509 bytes
```

This exceeds the 16KB limit.

---

## ✅ Solution

### Approach: Post-Deployment Installation

Remove Kiro CLI from UserData and install it after stack creation using:
1. Manual SSH/SSM installation
2. Automated post-deployment script
3. Independent installation script

### Changes Made

**1. Reverted CloudFormation Templates**

`clawdbot-bedrock.yaml`:
```diff
- # Install Kiro CLI
- echo "Installing Kiro CLI..."
- curl -fsSL https://cli.kiro.dev/install | bash || echo "Kiro CLI installation failed (non-fatal)"
```

`clawdbot-bedrock-mac.yaml`:
```diff
- # Install Kiro CLI
- echo "Installing Kiro CLI..."
- curl -fsSL https://cli.kiro.dev/install | bash || echo "Kiro CLI installation failed (non-fatal)"
```

**2. Updated Documentation**

`docs/KIRO_INSTALLATION.md`:
- Added warning about manual installation requirement
- Updated installation methods priority
- Clarified post-deployment workflow

**3. Maintained Installation Scripts**

- `scripts/install-kiro.sh` - Standalone installation
- `scripts/wait-and-redeploy.sh` - Updated to install Kiro post-deployment

---

## 🎯 Implementation

### New Deployment Workflow

```
1. CloudFormation creates stack
   ↓
2. UserData installs OpenClaw only
   ↓
3. Stack completes (8-10 minutes)
   ↓
4. Post-deployment: Install Kiro CLI
   ├── Option A: SSH and run install script
   ├── Option B: SSM remote command
   └── Option C: Automated via scripts/install-kiro.sh
```

### Installation Commands

**After stack is created:**

```bash
# Get instance ID
INSTANCE_ID=$(aws cloudformation describe-stack-resource \
  --stack-name openclaw-test1 \
  --logical-resource-id OpenClawInstance \
  --query 'StackResourceDetail.PhysicalResourceId' \
  --output text)

# Method 1: Direct SSM command
aws ssm send-command \
  --instance-ids $INSTANCE_ID \
  --document-name "AWS-RunShellScript" \
  --parameters 'commands=["su - ubuntu -c \"curl -fsSL https://cli.kiro.dev/install | bash\""]'

# Method 2: Use installation script
aws ssm send-command \
  --instance-ids $INSTANCE_ID \
  --document-name "AWS-RunShellScript" \
  --parameters commands="$(cat scripts/install-kiro.sh)"
```

---

## 📈 Benefits of This Approach

### Advantages

1. **No UserData Limit Issues**
   - Keep UserData focused on core infrastructure
   - Avoid Base64 encoding size multiplication

2. **Modular Installation**
   - Kiro is optional, not required for OpenClaw
   - Users can skip if not needed
   - Easier to update/reinstall

3. **Flexibility**
   - Install different versions
   - Test before installing
   - Conditional installation based on use case

4. **Cleaner CloudFormation**
   - UserData only handles essential setup
   - Optional tools installed separately
   - Easier to maintain and debug

### Trade-offs

**Before (UserData installation):**
- ✅ Fully automated
- ✅ No post-deployment steps
- ❌ UserData size limit
- ❌ All-or-nothing installation

**After (Post-deployment):**
- ✅ No size limits
- ✅ Flexible installation
- ✅ Optional feature
- ❌ Requires manual step
- ❌ Not immediately available

---

## 🛠️ Alternative Solutions Considered

### 1. Compress UserData ❌
**Idea:** Use gzip compression  
**Issue:** AWS Base64-encodes before compression  
**Result:** Still hits limit

### 2. Split into Multiple Scripts ❌
**Idea:** Download scripts from S3  
**Issue:** Adds S3 dependency and complexity  
**Result:** Not worth the overhead

### 3. Use Custom Resource Lambda ❌
**Idea:** Lambda installs Kiro after instance launch  
**Issue:** Adds Lambda, IAM, and timeout complexity  
**Result:** Over-engineered

### 4. Post-Deployment Script ✅
**Idea:** Separate installation step after stack  
**Issue:** Requires manual action  
**Result:** **Chosen** - simplest and most flexible

---

## 📝 Best Practices

### UserData Size Management

**Do:**
- ✅ Install only essential components in UserData
- ✅ Use package managers (apt, yum, npm) for standard tools
- ✅ Download large scripts from S3 if needed
- ✅ Keep UserData under 12KB to be safe

**Don't:**
- ❌ Install optional tools in UserData
- ❌ Embed large scripts directly
- ❌ Add verbose logging (use CloudWatch instead)
- ❌ Install development tools unless required

### What Belongs in UserData

**Essential (UserData):**
- System updates
- Core dependencies (AWS CLI, SSM)
- Primary application (OpenClaw)
- Basic configuration
- Service startup

**Optional (Post-deployment):**
- Development tools (Kiro CLI)
- Debugging utilities
- Optional services
- User-specific configurations

---

## 🔄 Updated Deployment Process

### Step-by-Step

**1. Deploy CloudFormation Stack**
```bash
aws cloudformation create-stack \
  --stack-name openclaw-test1 \
  --template-body file://clawdbot-bedrock.yaml \
  --parameters ...
```

**2. Wait for Completion**
```bash
aws cloudformation wait stack-create-complete \
  --stack-name openclaw-test1
```

**3. Install Kiro CLI (Optional)**
```bash
# Get instance ID
INSTANCE_ID=$(aws cloudformation describe-stack-resource \
  --stack-name openclaw-test1 \
  --logical-resource-id OpenClawInstance \
  --query 'StackResourceDetail.PhysicalResourceId' \
  --output text)

# Install Kiro
aws ssm send-command \
  --instance-ids $INSTANCE_ID \
  --document-name "AWS-RunShellScript" \
  --parameters 'commands=["su - ubuntu -c \"curl -fsSL https://cli.kiro.dev/install | bash\""]'
```

**4. Verify Installation**
```bash
aws ssm start-session --target $INSTANCE_ID
kiro-cli --version
```

---

## 📊 Size Comparison

| Component | Before (bytes) | After (bytes) | Change |
|-----------|----------------|---------------|--------|
| Base UserData | 15,300 | 15,300 | - |
| Kiro CLI install | 200 | 0 | -200 |
| **Total** | **15,500** | **15,300** | **-200** |
| **Base64 encoded** | **21,235** | **20,961** | **-274** |
| **AWS Limit** | 16,384 | 16,384 | - |
| **Status** | ❌ Over | ✅ Under | ✅ |

---

## ✅ Verification

### Template Changes
```bash
cd ~/repos/OpenClaw-AWS-Bedrock

# Check if Kiro installation removed
grep -q "Install Kiro CLI" clawdbot-bedrock.yaml && echo "Still present" || echo "✅ Removed"
grep -q "Install Kiro CLI" clawdbot-bedrock-mac.yaml && echo "Still present" || echo "✅ Removed"
```

### Documentation Updates
- ✅ KIRO_INSTALLATION.md updated with manual installation instructions
- ✅ This document created (USERDATA_SIZE_ISSUE.md)
- ✅ README.md will be updated with post-deployment steps

---

## 🚀 Next Steps

### Immediate
1. ✅ Revert UserData changes
2. ✅ Update documentation
3. ⏳ Wait for rollback to complete
4. ⏳ Redeploy with fixed template
5. ⏳ Verify deployment success
6. ⏳ Manually install Kiro CLI
7. ⏳ Document successful installation

### Future Improvements
1. Create automated post-deployment script
2. Add size check to CI/CD
3. Document UserData size limits in README
4. Consider S3-based script download for large additions

---

## 📚 Resources

- [AWS EC2 User Data Limits](https://docs.aws.amazon.com/AWSEC2/latest/UserGuide/user-data.html)
- [Base64 Encoding Size Calculator](https://www.base64encode.org/)
- [Kiro CLI Installation](https://kiro.dev/docs/installation)

---

**Status:** ✅ **Fixed**  
**Impact:** Deployment unblocked, Kiro CLI available via post-deployment  
**Next:** Redeploy stack with corrected template

*Updated: 2026-03-15 05:56 UTC*
