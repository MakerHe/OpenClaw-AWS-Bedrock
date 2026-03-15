# Kiro CLI Installation Guide

This guide covers Kiro CLI installation for OpenClaw deployments on AWS.

## ⚠️ Important: Manual Installation Required

Due to AWS UserData size limitations (16KB), Kiro CLI is **not automatically installed** during CloudFormation deployment.

**After your stack is deployed, install Kiro CLI manually using one of the methods below.**

## What is Kiro CLI?

Kiro CLI is an AI-powered code generation and automation tool that can:
- Generate scripts and code
- Analyze project structures
- Automate maintenance tasks
- Assist with documentation

## Installation Methods

### Method 1: Automatic (New CloudFormation Deployments)

Kiro CLI is now **automatically installed** in all new deployments using:
- `clawdbot-bedrock.yaml` (Linux/Graviton)
- `clawdbot-bedrock-mac.yaml` (macOS)

No action needed - Kiro will be available when the instance launches.

### Method 2: Manual Installation (Existing Instances)

#### Via SSH/SSM Session:

```bash
# Connect to your instance
aws ssm start-session --target i-INSTANCEID --region REGION

# As ubuntu user
curl -fsSL https://cli.kiro.dev/install | bash

# Verify installation
kiro-cli --version
```

#### Via Installation Script:

```bash
# Download and run the installation script
sudo bash /path/to/scripts/install-kiro.sh
```

The script (`scripts/install-kiro.sh`) handles:
- User detection
- Node.js verification
- Kiro installation
- Installation verification
- Logging to `/var/log/kiro-install.log`

### Method 3: Remote Installation via SSM

For existing instances without SSH access:

```bash
# Download the install script
curl -fsSL https://raw.githubusercontent.com/MakerHe/OpenClaw-AWS-Bedrock/main/scripts/install-kiro.sh -o /tmp/install-kiro.sh

# Run via SSM
COMMAND_ID=$(aws ssm send-command \
  --instance-ids i-INSTANCEID \
  --region REGION \
  --document-name "AWS-RunShellScript" \
  --parameters 'commands=["bash /tmp/install-kiro.sh"]' \
  --output text --query 'Command.CommandId')

# Check result
aws ssm get-command-invocation \
  --command-id $COMMAND_ID \
  --instance-id i-INSTANCEID \
  --region REGION
```

---

## Verification

After installation, verify Kiro CLI is working:

```bash
# Check version
kiro-cli --version

# Check location
which kiro-cli

# Test basic functionality
kiro-cli chat --no-interactive "Say hello"
```

Expected output:
```
kiro-cli 1.27.2
/home/ubuntu/.local/bin/kiro-cli
```

---

## Usage Examples

### Generate a Script

```bash
cd ~/repos/OpenClaw-AWS-Bedrock

kiro-cli chat --no-interactive --trust-all-tools \
  "Create a script to check CloudFormation stack status"
```

### Analyze Project

```bash
kiro-cli chat --no-interactive \
  "Analyze the project structure and list main components"
```

### Code Generation

```bash
kiro-cli chat --trust-all-tools \
  "Create a backup script that creates AMI snapshots"
```

---

## Configuration

### Trust All Tools (Bypass Confirmations)

For automation, use `--trust-all-tools`:

```bash
kiro-cli chat --no-interactive --trust-all-tools "your prompt"
```

⚠️ **Security Note:** Only use `--trust-all-tools` when you trust the prompt and understand what tools will be executed.

### Authentication (Optional)

For advanced features:

```bash
kiro-cli login
```

Follow the prompts to authenticate with your Kiro account.

---

## Troubleshooting

### Kiro Not Found

**Symptom:** `command not found: kiro-cli`

**Solutions:**

1. Check if installed:
   ```bash
   ls -la ~/.local/bin/kiro-cli
   ```

2. Add to PATH:
   ```bash
   export PATH="$HOME/.local/bin:$PATH"
   echo 'export PATH="$HOME/.local/bin:$PATH"' >> ~/.bashrc
   source ~/.bashrc
   ```

3. Reinstall:
   ```bash
   curl -fsSL https://cli.kiro.dev/install | bash
   ```

### Node.js Not Found

**Symptom:** Installation fails with "node: command not found"

**Solution:**

```bash
# Source NVM
export NVM_DIR="$HOME/.nvm"
[ -s "$NVM_DIR/nvm.sh" ] && . "$NVM_DIR/nvm.sh"

# Retry installation
curl -fsSL https://cli.kiro.dev/install | bash
```

### Permission Denied

**Symptom:** Cannot write to installation directory

**Solution:**

Ensure you're running as the ubuntu user (not root):

```bash
# If running as root, switch to ubuntu
su - ubuntu

# Then install
curl -fsSL https://cli.kiro.dev/install | bash
```

### Installation Hangs

**Symptom:** Installation appears stuck

**Solution:**

1. Check network connectivity:
   ```bash
   curl -I https://cli.kiro.dev/install
   ```

2. Try with verbose output:
   ```bash
   curl -fsSL https://cli.kiro.dev/install | bash -x
   ```

3. Check logs:
   ```bash
   tail -f /var/log/kiro-install.log  # if using install script
   ```

---

## Cost & Performance

### Local Installation Verified

| Metric | Value |
|--------|-------|
| **Version** | 1.27.2 |
| **Installation Time** | ~10-30 seconds |
| **Disk Space** | ~50 MB |
| **Dependencies** | Node.js 14+ |

### Usage Costs

Kiro CLI uses credits for AI operations:

| Operation | Time | Credits | Cost (approx) |
|-----------|------|---------|---------------|
| Project scan | 9s | 0.06 | ~$0.001 |
| Script generation | 44s | 0.53 | ~$0.01 |
| Simple query | 3s | 0.02 | ~$0.0003 |

**Typical Monthly Cost:** $1-5 for light usage (50-100 operations)

---

## Integration with OpenClaw

### Use Cases

**1. Maintenance Scripts:**
- Generate health check scripts
- Create backup automation
- Build monitoring tools

**2. Documentation:**
- Auto-generate deployment guides
- Create API documentation
- Build troubleshooting guides

**3. Code Analysis:**
- Review CloudFormation templates
- Analyze project structure
- Find optimization opportunities

**4. Automation:**
- Generate CI/CD workflows
- Create testing scripts
- Build deployment automation

### Example: Generated Script

The `scripts/quick-status.sh` script was generated by Kiro CLI:

```bash
cd ~/repos/OpenClaw-AWS-Bedrock
./scripts/quick-status.sh
```

Output:
```
🦞 OpenClaw Quick Status  (region: ap-northeast-1)
════════════════════════════════════════

📦 CloudFormation Stacks
────────────────────────
  🟢 openclaw-bedrock — CREATE_COMPLETE
  🟢 openclaw-test1 — CREATE_COMPLETE

🖥️  EC2 Instances
────────────────────────
  🟢 i-02d0e970eac68c87c (t4g.large) — running
  🟢 i-05be3a1bfad22f5d8 (t4g.large) — running
...
```

---

## Resources

- **Kiro CLI Website:** https://kiro.dev
- **Documentation:** https://kiro.dev/docs
- **Installation Script:** `scripts/install-kiro.sh`
- **Test Report:** `KIRO_CLI_TEST_REPORT.md`
- **GitHub:** https://github.com/kirodev/kiro-cli

---

## Update History

- **2026-03-15:** Initial implementation
  - Added to CloudFormation templates
  - Created installation script
  - Tested on openclaw-bedrock (✅ working)
  - openclaw-test1 ready for manual install

---

*For questions or issues, see the [main documentation](README.md) or [troubleshooting guide](TROUBLESHOOTING.md).*
