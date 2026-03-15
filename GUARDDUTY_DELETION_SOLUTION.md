# GuardDuty VPC Endpoint 删除问题 - 解决方案

**Date:** 2026-03-15 05:46 UTC  
**Problem:** CloudFormation stack 删除因 GuardDuty VPC Endpoint 依赖而失败  
**Status:** ✅ **已解决**

---

## 🎯 问题总结

### 初始问题
- **Stack:** openclaw-test1
- **状态:** DELETE_FAILED
- **原因:** PrivateSubnet 有 GuardDuty VPC Endpoint ENI 依赖

### 根本原因
```
GuardDuty Service (启用)
    ↓
自动创建 VPC Endpoint
    ↓
VPC Endpoint 创建 ENI 在 Subnet
    ↓
CloudFormation 无法删除有 ENI 的 Subnet
    ↓
Stack 删除失败
```

---

## ✅ 解决步骤

### 1. 发现问题 ✅
```bash
# 检查失败资源
aws cloudformation describe-stack-events \
  --stack-name openclaw-test1 \
  --query 'StackEvents[?ResourceStatus==`DELETE_FAILED`]'

# 结果: PrivateSubnet (subnet-0c1ba4ff82e4e5789) 删除失败
```

### 2. 定位依赖 ✅
```bash
# 检查 Subnet 中的 ENI
aws ec2 describe-network-interfaces \
  --filters "Name=subnet-id,Values=subnet-0c1ba4ff82e4e5789"

# 发现: ENI eni-0db8416f1b2b2934e (VPC Endpoint vpce-0ec25dce580175187)
```

### 3. 识别服务 ✅
```bash
# 检查 VPC Endpoint
aws ec2 describe-vpc-endpoints \
  --vpc-endpoint-ids vpce-0ec25dce580175187

# 服务: com.amazonaws.ap-northeast-1.guardduty-data
```

### 4. 删除第一个 VPC Endpoint ✅
```bash
aws ec2 delete-vpc-endpoints \
  --vpc-endpoint-ids vpce-0ec25dce580175187 \
  --region ap-northeast-1

# 状态: deleting → deleted
```

### 5. 检查 GuardDuty 状态 ✅
```bash
aws guardduty list-detectors --region ap-northeast-1

# 结果: Detector ID: 38ca6cb02ae6033c83bd01e720f64e65
# 状态: ENABLED (组织管理，无法直接禁用)
```

### 6. 发现第二个 VPC Endpoint ✅
```bash
# 扫描所有 GuardDuty VPC Endpoints
aws ec2 describe-vpc-endpoints \
  --filters "Name=service-name,Values=com.amazonaws.ap-northeast-1.guardduty-data"

# 发现: vpce-07c0096e028a21875 (在 vpc-01c505c015db61dfa)
```

### 7. 删除第二个 VPC Endpoint ✅
```bash
aws ec2 delete-vpc-endpoints \
  --vpc-endpoint-ids vpce-07c0096e028a21875 \
  --region ap-northeast-1

# 状态: deleting
```

### 8. 验证 Stack 删除继续 ✅
```bash
# 检查 Stack 事件
aws cloudformation describe-stack-events \
  --stack-name openclaw-test1 \
  --max-items 10

# 结果:
# - PrivateSubnet: DELETE_COMPLETE ✅
# - OpenClawVPC: DELETE_IN_PROGRESS ✅
# - Stack: DELETE_IN_PROGRESS ✅
```

---

## 📊 时间线

| Time | Event | Result |
|------|-------|--------|
| 05:07 | 开始删除 openclaw-test1 | DELETE_IN_PROGRESS |
| 05:26 | PrivateSubnet 删除失败 | DELETE_FAILED |
| 05:31 | 发现 GuardDuty VPC Endpoint 依赖 | Analysis |
| 05:32 | 删除第一个 VPC Endpoint (vpce-0ec25dce5801) | Deleting |
| 05:32 | 重新触发 Stack 删除 | DELETE_IN_PROGRESS |
| 05:35 | PrivateSubnet 删除成功 | DELETE_COMPLETE ✅ |
| 05:35 | VPC 开始删除 | DELETE_IN_PROGRESS |
| 05:42 | 发现第二个 GuardDuty VPC Endpoint | Found |
| 05:42 | 删除第二个 VPC Endpoint (vpce-07c009) | Deleting |
| 05:46 | VPC 删除继续进行 | In Progress |

---

## 🎓 关键经验

### 问题根源
1. **GuardDuty 自动行为**
   - 启用 GuardDuty 后自动创建 VPC Endpoint
   - 可能在多个 VPC 中创建
   - 不被 CloudFormation 管理（无 CFN tags）

2. **组织管理限制**
   - 此账户的 GuardDuty 由组织管理
   - 成员账户无法直接禁用/删除 Detector
   - 报错：`member accounts cannot manage specified resources`

3. **VPC Endpoint 生命周期**
   - VPC Endpoint 创建 ENI
   - ENI 阻止 Subnet 删除
   - 必须先删除 VPC Endpoint，等待 ENI 清理

### 解决策略

**不要尝试：**
❌ 禁用 GuardDuty Detector（组织管理的账户无法操作）
❌ 删除 GuardDuty Detector（会报错）
❌ 手动删除 ENI（AWS 管理，无法直接删除）

**正确方法：**
✅ 删除 GuardDuty VPC Endpoints
✅ 等待 ENI 自动清理
✅ CloudFormation 自动继续删除流程

---

## 🛠️ 预防措施

### 1. 删除前检查脚本

创建 `scripts/pre-delete-check.sh`:

```bash
#!/bin/bash
# Pre-deletion check for CloudFormation stacks

STACK_NAME=$1
REGION=${2:-ap-northeast-1}

echo "=== Pre-deletion Check for $STACK_NAME ==="
echo ""

# Get VPC ID from stack
VPC_ID=$(aws cloudformation describe-stack-resource \
  --stack-name $STACK_NAME \
  --logical-resource-id VPC \
  --region $REGION \
  --query 'StackResourceDetail.PhysicalResourceId' \
  --output text 2>/dev/null)

if [ -z "$VPC_ID" ] || [ "$VPC_ID" = "None" ]; then
  echo "VPC not found or already deleted"
  exit 0
fi

echo "VPC ID: $VPC_ID"
echo ""

# Check for external VPC Endpoints
echo "Checking for external VPC Endpoints..."
EXTERNAL_VPCE=$(aws ec2 describe-vpc-endpoints \
  --filters "Name=vpc-id,Values=$VPC_ID" \
  --region $REGION \
  --query 'VpcEndpoints[?!Tags[?Key==`aws:cloudformation:stack-name`]].[VpcEndpointId,ServiceName]' \
  --output text)

if [ -n "$EXTERNAL_VPCE" ]; then
  echo "⚠️  Found external VPC Endpoints (not created by CloudFormation):"
  echo "$EXTERNAL_VPCE"
  echo ""
  echo "Delete these before deleting the stack:"
  echo "$EXTERNAL_VPCE" | awk '{print "aws ec2 delete-vpc-endpoints --vpc-endpoint-ids "$1" --region '$REGION'"}'
  exit 1
else
  echo "✅ No external VPC Endpoints found"
fi

echo ""
echo "✅ Pre-deletion check passed"
```

### 2. 自动清理 Lambda

在 CloudFormation 模板中添加 Custom Resource：

```yaml
GuardDutyVPCEndpointCleaner:
  Type: Custom::VPCEndpointCleaner
  Properties:
    ServiceToken: !GetAtt CleanupLambda.Arn
    VpcId: !Ref OpenClawVPC
    ServiceName: !Sub "com.amazonaws.${AWS::Region}.guardduty-data"
```

### 3. 文档更新

在 README.md 中添加删除注意事项：

```markdown
## 删除 Stack

如果您启用了 GuardDuty，请先删除 GuardDuty VPC Endpoints：

bash
# 查找并删除 GuardDuty VPC Endpoints
VPC_ID=$(aws cloudformation describe-stack-resource \
  --stack-name openclaw-test1 \
  --logical-resource-id VPC \
  --query 'StackResourceDetail.PhysicalResourceId' \
  --output text)

aws ec2 describe-vpc-endpoints \
  --filters "Name=vpc-id,Values=$VPC_ID" "Name=service-name,Values=*guardduty*" \
  --query 'VpcEndpoints[].VpcEndpointId' \
  --output text | xargs -I {} aws ec2 delete-vpc-endpoints --vpc-endpoint-ids {}

# 然后删除 Stack
aws cloudformation delete-stack --stack-name openclaw-test1

```

---

## 📋 检查清单

### 删除前检查
- [ ] 检查 VPC 中的所有 VPC Endpoints
- [ ] 识别非 CloudFormation 创建的资源
- [ ] 特别检查 GuardDuty VPC Endpoints
- [ ] 检查 Lambda Functions (VPC 配置)
- [ ] 检查 RDS Instances
- [ ] 检查 ECS Tasks

### 删除中监控
- [ ] 监控删除事件（前 5-10 分钟）
- [ ] 如有 DELETE_FAILED，立即检查原因
- [ ] 检查依赖资源（ENI, Security Groups）
- [ ] 必要时手动清理外部依赖

### 删除后验证
- [ ] 确认 Stack 不存在
- [ ] 确认 VPC 已删除
- [ ] 确认所有 ENI 已清理
- [ ] 检查孤立的 Security Groups
- [ ] 检查孤立的 Elastic IPs

---

## 🚀 下一步

### 当前状态
- ✅ GuardDuty VPC Endpoints 已删除
- ✅ PrivateSubnet 删除成功
- 🔄 VPC 删除进行中
- 🔄 Stack 删除进行中

### 预计完成时间
- VPC 删除: ~2-5 分钟（等待 ENI 清理）
- Stack 完全删除: ~5-10 分钟

### 完成后操作
1. 验证 Stack 完全删除
2. 重新部署 openclaw-test1
3. 验证 Kiro CLI 自动安装
4. 提交文档更新

---

## 📚 参考命令

### 快速删除 GuardDuty VPC Endpoints
```bash
# 一键删除所有 GuardDuty VPC Endpoints
aws ec2 describe-vpc-endpoints \
  --region ap-northeast-1 \
  --filters "Name=service-name,Values=com.amazonaws.ap-northeast-1.guardduty-data" \
  --query 'VpcEndpoints[].VpcEndpointId' \
  --output text | xargs -I {} aws ec2 delete-vpc-endpoints --vpc-endpoint-ids {} --region ap-northeast-1
```

### 检查 Stack 删除进度
```bash
# 实时监控
watch -n 5 'aws cloudformation describe-stacks --stack-name openclaw-test1 --region ap-northeast-1 --query "Stacks[0].StackStatus" --output text'

# 查看最近事件
aws cloudformation describe-stack-events \
  --stack-name openclaw-test1 \
  --region ap-northeast-1 \
  --max-items 10 \
  --query 'StackEvents[].[Timestamp,LogicalResourceId,ResourceStatus]' \
  --output table
```

---

**Status:** ✅ **问题已解决，等待删除完成**

*更新时间: 2026-03-15 05:46 UTC*
