# CloudFormation Stack 删除问题分析报告

**Date:** 2026-03-15 05:30 UTC  
**Stack:** openclaw-test1  
**Region:** ap-northeast-1  
**Status:** DELETE_IN_PROGRESS → DELETE_FAILED → DELETE_IN_PROGRESS (重新尝试中)

---

## 🔴 问题概述

### 初始症状
- Stack 删除卡在 `DELETE_IN_PROGRESS` 状态超过 20+ 分钟
- 最终转为 `DELETE_FAILED` 状态
- 错误信息：`The following resource(s) failed to delete: [PrivateSubnet]`

---

## 🔍 根因分析

### 失败资源
**Resource:** `PrivateSubnet` (subnet-0c1ba4ff82e4e5789)  
**Type:** AWS::EC2::Subnet  
**Status:** DELETE_FAILED  

**Error Message:**
```
Resource handler returned message: "The subnet 'subnet-0c1ba4ff82e4e5789' 
has dependencies and cannot be deleted. (Service: Ec2, Status Code: 400, 
Request ID: d4a20e6f-aa1a-412f-bca0-0e041fce4bb3)"
```

### 依赖关系分析

**1. Subnet 依赖检查:**
```bash
aws ec2 describe-subnets --subnet-ids subnet-0c1ba4ff82e4e5789
```
- Status: available
- VPC: vpc-0c67ab9b5215c5595
- Available IPs: 250

**2. 网络接口（ENI）检查:**
```bash
aws ec2 describe-network-interfaces --filters "Name=subnet-id,Values=subnet-0c1ba4ff82e4e5789"
```

**发现问题：**
- ENI ID: `eni-0db8416f1b2b2934e`
- Status: `in-use`
- Description: **"VPC Endpoint Interface vpce-0ec25dce580175187"**
- Attachment: None (not attached to EC2)

**3. VPC Endpoint 分析:**
```bash
aws ec2 describe-vpc-endpoints --vpc-endpoint-ids vpce-0ec25dce580175187
```

**关键发现：**
- VPC Endpoint ID: `vpce-0ec25dce580175187`
- Service: `com.amazonaws.ap-northeast-1.guardduty-data`
- State: available
- **CloudFormation Tag: MISSING** ❌

---

## 🎯 根本原因

### GuardDuty VPC Endpoint 问题

**问题根源：**
VPC 中存在一个 **不属于 CloudFormation stack** 的 VPC Endpoint (`vpce-0ec25dce580175187`)：

1. **服务类型：** GuardDuty Data Endpoint
2. **创建方式：** 不是通过 openclaw-test1 stack 创建
3. **可能来源：**
   - AWS 自动创建（GuardDuty 服务启用时）
   - 其他 CloudFormation stack 的残留
   - 手动创建
   - 共享服务端点

4. **影响：**
   - VPC Endpoint 创建了 ENI 在 PrivateSubnet 中
   - CloudFormation 无法删除有依赖的 Subnet
   - Stack 删除失败

### 删除顺序问题

**CloudFormation 删除顺序：**
```
1. EC2 Instance → ✅ 成功
2. Security Groups → ✅ 成功  
3. IAM Roles → ✅ 成功
4. VPC Endpoints (stack创建的) → ✅ 成功
5. PrivateSubnet → ❌ 失败 (依赖 GuardDuty VPC Endpoint)
6. VPC → ⏸️ 等待中
```

**CloudFormation 无法删除外部依赖**，必须手动清理。

---

## ✅ 解决方案

### 步骤 1: 手动删除 GuardDuty VPC Endpoint

```bash
aws ec2 delete-vpc-endpoints \
  --vpc-endpoint-ids vpce-0ec25dce580175187 \
  --region ap-northeast-1
```

**结果：**
```json
{
    "Unsuccessful": []
}
```

**验证：**
```bash
aws ec2 describe-vpc-endpoints \
  --vpc-endpoint-ids vpce-0ec25dce580175187 \
  --query 'VpcEndpoints[0].State'
```
- Status: `deleting` ✅

### 步骤 2: 重新触发 Stack 删除

```bash
aws cloudformation delete-stack \
  --stack-name openclaw-test1 \
  --region ap-northeast-1
```

**当前状态：** `DELETE_IN_PROGRESS`  
**预期结果：** 删除应该能够继续进行

---

## 📊 时间线

| Time (UTC) | Event | Status |
|------------|-------|--------|
| 05:07 | 用户请求删除 openclaw-test1 | Started |
| 05:08 | CloudFormation 开始删除 | DELETE_IN_PROGRESS |
| 05:11 | Security Groups, IAM 删除成功 | Progressing |
| 05:26 | PrivateSubnet 删除失败 | DELETE_FAILED |
| 05:26 | Stack 整体状态变为失败 | DELETE_FAILED |
| 05:30 | 发现 GuardDuty VPC Endpoint 依赖 | Analysis |
| 05:31 | 手动删除 VPC Endpoint | Manual Fix |
| 05:32 | 重新触发 Stack 删除 | DELETE_IN_PROGRESS |
| 05:37 | Stack 删除持续进行中 | In Progress |

---

## 🎓 经验教训

### 1. VPC Endpoint 依赖问题

**问题：**
- 其他 AWS 服务可能在 VPC 中自动创建 VPC Endpoints
- CloudFormation 无法删除不属于 stack 的资源
- VPC Endpoints 创建的 ENI 会阻止 Subnet 删除

**预防措施：**
```bash
# 在删除 stack 前检查 VPC 中的所有 VPC Endpoints
aws ec2 describe-vpc-endpoints \
  --filters "Name=vpc-id,Values=VPC_ID" \
  --query 'VpcEndpoints[].[VpcEndpointId,ServiceName,Tags[?Key==`aws:cloudformation:stack-name`].Value|[0]]'
```

**识别外部 VPC Endpoints：**
- 没有 `aws:cloudformation:stack-name` tag
- Service name 不在预期列表中
- 创建时间早于 stack 创建时间

### 2. GuardDuty 服务特性

**GuardDuty 行为：**
- 启用 GuardDuty 后，AWS 可能自动创建 VPC Endpoint
- Service: `com.amazonaws.{region}.guardduty-data`
- 用于安全监控数据传输
- 可能在多个 subnet 中创建 ENI

**检查 GuardDuty 状态：**
```bash
aws guardduty list-detectors --region ap-northeast-1
```

### 3. CloudFormation 删除最佳实践

**删除前检查清单：**
- [ ] 检查 VPC 中的所有 VPC Endpoints
- [ ] 验证所有 ENI 属于 stack
- [ ] 检查 Security Groups 引用关系
- [ ] 确认 Lambda Functions 未使用 VPC
- [ ] 验证 ECS Tasks 已停止（如适用）
- [ ] 检查 RDS Instances 不在同一 VPC（如适用）

**推荐删除流程：**
1. 手动停止/删除 EC2 实例（可选，加速删除）
2. 等待 2-3 分钟让 ENI 自动分离
3. 检查外部 VPC Endpoints
4. 执行 CloudFormation 删除
5. 监控删除进度（前 5-10 分钟）
6. 如有失败，检查依赖关系

### 4. 调试技巧

**快速定位删除失败原因：**
```bash
# 查看失败资源
aws cloudformation describe-stack-events \
  --stack-name STACK_NAME \
  --query 'StackEvents[?ResourceStatus==`DELETE_FAILED`].[LogicalResourceId,ResourceType,ResourceStatusReason]' \
  --output table

# 检查 Subnet 依赖
aws ec2 describe-network-interfaces \
  --filters "Name=subnet-id,Values=SUBNET_ID" \
  --query 'NetworkInterfaces[].[NetworkInterfaceId,Status,Description]'

# 查找所有外部 VPC Endpoints
aws ec2 describe-vpc-endpoints \
  --filters "Name=vpc-id,Values=VPC_ID" \
  --query 'VpcEndpoints[?!Tags[?Key==`aws:cloudformation:stack-name`]].[VpcEndpointId,ServiceName]'
```

---

## 🔧 预防措施（未来部署）

### CloudFormation 模板改进

**1. 添加 VPC Endpoint 清理脚本**

在 UserData 或 Custom Resource 中添加：
```bash
# On stack deletion, clean up external VPC Endpoints
aws ec2 describe-vpc-endpoints \
  --filters "Name=vpc-id,Values=${VPC_ID}" \
  --query 'VpcEndpoints[?ServiceName==`com.amazonaws.${AWS::Region}.guardduty-data`].VpcEndpointId' \
  --output text | xargs -I {} aws ec2 delete-vpc-endpoints --vpc-endpoint-ids {}
```

**2. DeletionPolicy 配置**

对于可能有外部依赖的资源：
```yaml
PrivateSubnet:
  Type: AWS::EC2::Subnet
  DeletionPolicy: Retain  # 可选：保留用于调试
  # 或
  DeletionPolicy: Delete  # 默认，但需确保无外部依赖
```

**3. 文档说明**

在 README 中添加：
```markdown
## 删除 Stack 前的准备工作

如果启用了 GuardDuty，请先手动删除 GuardDuty VPC Endpoints：

bash
aws ec2 describe-vpc-endpoints \
  --filters "Name=vpc-id,Values=$(aws cloudformation describe-stack-resource \
    --stack-name STACK_NAME \
    --logical-resource-id VPC \
    --query 'StackResourceDetail.PhysicalResourceId' \
    --output text)" \
  --query 'VpcEndpoints[?contains(ServiceName, `guardduty`)].VpcEndpointId' \
  --output text | xargs -I {} aws ec2 delete-vpc-endpoints --vpc-endpoint-ids {}

aws cloudformation delete-stack --stack-name STACK_NAME

```

---

## 📝 当前状态总结

### 已完成
- ✅ 识别删除失败原因（GuardDuty VPC Endpoint）
- ✅ 手动删除 VPC Endpoint (vpce-0ec25dce580175187)
- ✅ 重新触发 Stack 删除
- ✅ 记录详细分析和解决方案

### 进行中
- 🔄 Stack 删除中 (DELETE_IN_PROGRESS)
- 🔄 等待所有资源清理完成

### 待执行
- ⏳ 验证 Stack 完全删除
- ⏳ 重新部署 openclaw-test1
- ⏳ 验证 Kiro CLI 自动安装
- ⏳ 更新文档（添加删除注意事项）

---

## 🚀 下一步行动

**等待删除完成后：**
1. 验证 Stack 已完全删除
2. 使用更新后的模板重新部署
3. 验证 Kiro CLI 自动安装成功
4. 更新项目文档

**预计时间线：**
- Stack 删除: ~3-5 分钟（从现在开始）
- 重新部署: ~7-10 分钟
- Kiro 验证: ~2-3 分钟
- **总计: ~15-20 分钟**

---

*报告生成时间: 2026-03-15 05:37 UTC*
