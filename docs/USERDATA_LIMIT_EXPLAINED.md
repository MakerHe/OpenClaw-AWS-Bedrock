# UserData Size Limit - Detailed Explanation

## 📋 Background

### What is UserData?

UserData is a script that runs automatically when an EC2 instance first launches. In CloudFormation, it's commonly used to:
- Install software packages
- Configure the system
- Start services
- Set up the application

### The 16KB Limit

**AWS Constraint:** EC2 UserData is limited to **16,384 bytes (16KB)** of raw data.

**Why this limit exists:**
1. **Boot Performance** - UserData is loaded into instance metadata at boot time
2. **Metadata Service** - EC2 metadata service has size constraints
3. **Historical Reasons** - Limit existed since early EC2 days for simplicity

**Important:** This is the **final encoded size**, not the script length in lines.

---

## 🔍 How We Hit the Limit

### Our UserData Contents

The `clawdbot-bedrock.yaml` template includes a comprehensive setup script that installs:

1. **System Updates** (~200 bytes)
   ```bash
   apt-get update
   apt-get upgrade -y
   apt-get install -y unzip curl
   ```

2. **AWS CLI v2** (~500 bytes)
   ```bash
   curl "https://awscli.amazonaws.com/..." -o "awscliv2.zip"
   unzip -q awscliv2.zip
   ./aws/install
   ```

3. **SSM Agent** (~200 bytes)
   ```bash
   snap start amazon-ssm-agent
   ```

4. **Docker** (~800 bytes - conditional)
   ```bash
   install -m 0755 -d /etc/apt/keyrings
   curl -fsSL https://download.docker.com/.../gpg ...
   apt-get install -y docker-ce ...
   ```

5. **Node.js via NVM** (~1,500 bytes)
   ```bash
   curl -fsSL "https://raw.githubusercontent.com/nvm-sh/nvm/${NVM_VERSION}/install.sh" ...
   nvm install 22
   ```

6. **OpenClaw** (~2,000 bytes)
   ```bash
   npm install -g openclaw@latest --timeout=300000
   openclaw gateway install
   ```

7. **Configuration** (~3,000 bytes)
   ```bash
   # AWS region setup
   # Environment variables
   # OpenClaw config JSON
   # Gateway setup
   ```

8. **Service Management** (~1,500 bytes)
   ```bash
   # Systemd setup
   # Wait conditions
   # Status checks
   ```

9. **CloudFormation Signals** (~500 bytes)
   ```bash
   /usr/local/bin/cfn-signal ...
   ```

**Total without Kiro:** ~15,200 bytes (raw script)

### Adding Kiro CLI

When we added Kiro CLI installation:

```bash
# Install Kiro CLI
echo "Installing Kiro CLI..."
curl -fsSL https://cli.kiro.dev/install | bash || echo "Kiro CLI installation failed (non-fatal)"
```

This added ~200 bytes to the script.

### The Problem: Base64 Encoding

CloudFormation **Base64-encodes** UserData before sending to EC2:

```
Original script: 15,400 bytes
Base64 encoded: 15,400 × 1.37 ≈ 21,098 bytes
AWS Limit: 16,384 bytes
Result: ❌ FAILED
```

**Base64 encoding increases size by ~37%** because:
- It uses 6 bits per character instead of 8
- 3 bytes → 4 characters
- Padding added for alignment

---

## ❌ The Failure

### Error Message

```
Resource handler returned message: "User data is limited to 16384 bytes 
(Service: Ec2, Status Code: 400, Request ID: a03be83a-2c29-4d83-a287-45fffebc6e1b)"
```

### What Happened

1. CloudFormation template parsed ✅
2. UserData script Base64-encoded ✅
3. EC2 API called with encoded UserData ❌
4. AWS rejected: encoded size > 16KB
5. Stack creation **ROLLBACK_IN_PROGRESS**
6. All resources deleted

**Result:** Complete deployment failure, 10+ minutes wasted.

---

## ✅ Solutions Considered

### Option 1: Compress UserData ❌

**Idea:** Use gzip compression before Base64 encoding

```bash
UserData:
  Fn::Base64: !Sub |
    #!/bin/bash
    echo "H4sIAAAAAAAAA..." | base64 -d | gunzip | bash
```

**Why we rejected:**
- Still needs Base64 encoding (AWS requirement)
- Compression ratio not enough for our case
- Harder to debug and maintain
- Only saves ~2-3KB after encoding

---

### Option 2: Download Script from S3 ❌

**Idea:** Minimal UserData that downloads the real script

```bash
#!/bin/bash
aws s3 cp s3://my-bucket/setup.sh - | bash
```

**Why we rejected:**
- Adds S3 dependency (bucket creation, permissions)
- More complex setup for users
- S3 costs (minimal but exists)
- Requires IAM policy changes
- Script versioning becomes harder

---

### Option 3: External Package Repository ❌

**Idea:** Create a DEB/RPM package with all setup

```bash
#!/bin/bash
curl https://releases.openclaw.ai/setup.deb -o setup.deb
dpkg -i setup.deb
```

**Why we rejected:**
- Requires maintaining package repository
- Platform-specific packages (Ubuntu, AL2, etc.)
- Signing keys and trust setup
- Overkill for this use case

---

### Option 4: Lambda Custom Resource ❌

**Idea:** Use Lambda to run setup after instance launch

```yaml
SetupLambda:
  Type: AWS::Lambda::Function
  Properties:
    Runtime: python3.11
    Handler: index.handler
    Code:
      ZipFile: |
        import boto3
        def handler(event, context):
          ssm = boto3.client('ssm')
          # Run setup commands via SSM
```

**Why we rejected:**
- Over-engineered for simple install
- Lambda timeout (15 minutes max)
- SSM wait delays
- More moving parts = more failure points
- Debugging harder

---

### Option 5: Post-Deployment Manual Step ✅

**Idea:** Remove Kiro from UserData, install after deployment

**Why we chose this:**

1. **Simplest Solution**
   - No new dependencies (S3, Lambda, etc.)
   - Easy to understand and debug
   - Works for all users

2. **Kiro is Optional**
   - Not required for OpenClaw to function
   - Developer tool, not core infrastructure
   - Users can choose if they want it

3. **Clear Documentation**
   - Installation steps in `docs/KIRO_INSTALLATION.md`
   - Multiple methods provided (SSH, SSM, script)
   - Takes 1-2 minutes post-deployment

4. **Flexibility**
   - Users can install different Kiro versions
   - Can skip if not needed
   - Can test before installing

5. **Maintainability**
   - UserData stays under limit
   - Room for future additions
   - Easier to troubleshoot

---

## 🛠️ Our Implementation

### UserData (Core Infrastructure Only)

```yaml
UserData:
  Fn::Base64: !Sub |
    #!/bin/bash
    # System updates
    # AWS CLI
    # SSM Agent
    # Docker (optional)
    # Node.js
    # OpenClaw  ← Core ends here
    # Configuration
    # Service start
```

**Size:** ~15,300 bytes → ~20,961 bytes encoded (✅ under 16KB)

### Post-Deployment (Optional Tools)

**Manual Kiro Installation:**

```bash
# Option 1: SSH/SSM direct
aws ssm start-session --target INSTANCE_ID
curl -fsSL https://cli.kiro.dev/install | bash

# Option 2: Automated script
./scripts/install-kiro.sh INSTANCE_ID

# Option 3: Remote SSM command
aws ssm send-command --instance-ids INSTANCE_ID \
  --document-name "AWS-RunShellScript" \
  --parameters 'commands=["su - ubuntu -c \"curl -fsSL https://cli.kiro.dev/install | bash\""]'
```

**Time:** 1-2 minutes  
**Complexity:** Simple one-liner

---

## 📊 Comparison

| Approach | Pros | Cons | Complexity | Result |
|----------|------|------|------------|--------|
| **Keep in UserData** | Fully automated | Hits 16KB limit | Low | ❌ Failed |
| **Compress** | Smaller script | Still too large | Medium | ❌ Not enough |
| **S3 Download** | No size limit | S3 dependency | Medium | ⚠️ Works but complex |
| **Lambda** | Flexible | Over-engineered | High | ⚠️ Works but overkill |
| **Manual Install** | Simple, flexible | One extra step | Low | ✅ **Chosen** |

---

## 🎯 Best Practices

### What Belongs in UserData

**Essential (UserData):**
- ✅ System packages (aws-cli, ssm)
- ✅ Core application (OpenClaw)
- ✅ Required dependencies (Node.js)
- ✅ Service configuration
- ✅ Auto-start setup

**Optional (Post-Deployment):**
- ❌ Development tools (Kiro CLI, jq, etc.)
- ❌ User-specific tools
- ❌ Debugging utilities
- ❌ Optional integrations

### Size Management Tips

1. **Remove comments** from production UserData
   ```bash
   # ❌ This comment takes space
   apt-get update  # Also this
   
   # ✅ Better
   apt-get update
   ```

2. **Combine commands** when possible
   ```bash
   # ❌ Multiple lines
   apt-get update
   apt-get upgrade -y
   apt-get install -y curl
   
   # ✅ One line
   apt-get update && apt-get upgrade -y && apt-get install -y curl
   ```

3. **Use variables** to avoid repetition
   ```bash
   # ✅ Good
   REGION=${AWS::Region}
   aws s3 cp s3://bucket-$REGION/file1 .
   aws s3 cp s3://bucket-$REGION/file2 .
   ```

4. **External scripts** for large logic
   ```bash
   # ✅ If script is large, externalize it
   curl https://setup.example.com/install.sh | bash
   ```

5. **Keep verbose logging** optional
   ```bash
   # ❌ Verbose
   echo "Starting step 1..."
   do_step_1
   echo "Step 1 complete"
   echo "Starting step 2..."
   
   # ✅ Concise
   do_step_1
   do_step_2
   ```

---

## 📝 Documentation Strategy

### In CHANGELOG.md

```markdown
### UserData Size Limit

**Issue:** CloudFormation UserData is limited to 16KB. Adding too many 
setup scripts can exceed this limit.

**Solution:** Kiro CLI installation moved to post-deployment manual step. 
See `docs/KIRO_INSTALLATION.md` for instructions.
```

**Why minimal:**
- Most users won't hit this issue
- Technical details in separate doc
- Actionable solution provided

### In docs/KIRO_INSTALLATION.md

**Full installation guide:**
- Why manual installation needed
- Multiple installation methods
- Step-by-step instructions
- Troubleshooting

---

## 🎓 Lessons Learned

### 1. Base64 Encoding Impact

**Mistake:** Forgot that CloudFormation Base64-encodes UserData

**Learning:** Always calculate: `script_size × 1.37` for actual limit

### 2. Optional vs Essential

**Mistake:** Treating all tools as equally important

**Learning:** Core infrastructure in UserData, tools post-deployment

### 3. User Experience

**Mistake:** Trying to automate everything upfront

**Learning:** Sometimes a 2-minute manual step is better than complex automation

### 4. Documentation

**Mistake:** Not documenting the "why" behind decisions

**Learning:** Future maintainers need to understand constraints

---

## 🔮 Future Considerations

### If We Need More Space

**Short-term:**
1. Move Docker installation to separate script
2. Simplify OpenClaw config (use defaults)
3. Remove verbose logging

**Long-term:**
1. Create OpenClaw AMI (pre-installed)
2. Use AWS Systems Manager Distributor
3. Implement proper package management

### Monitoring

Track UserData size in CI/CD:

```bash
# In pre-commit hook or CI
USERDATA_SIZE=$(yq eval '.Resources.OpenClawInstance.Properties.UserData' \
  clawdbot-bedrock.yaml | wc -c)
ENCODED_SIZE=$((USERDATA_SIZE * 137 / 100))

if [ $ENCODED_SIZE -gt 14000 ]; then
  echo "⚠️  UserData approaching 16KB limit: ${ENCODED_SIZE} bytes"
fi
```

---

## ✅ Summary

**Problem:** AWS limits UserData to 16KB (encoded), we exceeded it

**Root Cause:** Base64 encoding increases size by 37%

**Solution:** Move optional tools (Kiro CLI) to post-deployment

**Trade-off:** One extra manual step vs. complex workarounds

**Result:** Simple, maintainable, works for all users

**Time Impact:** 2 minutes post-deployment vs. 0 minutes (fully automated)

**Complexity Reduction:** Kept UserData simple and under control

---

**Key Takeaway:** Sometimes the simplest solution (manual step) is better than a complex automated one, especially for optional features.
