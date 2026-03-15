# 分支策略 - 快速参考

## 📋 当前状态

```
main          ●─────────────────── (生产)
               ↓
optimize-s.u. ●───●───●───●──────  (PR #46, +14 commits) ✅ 待合并
               
dev           ●─────────────────── (新建, 空) 
               
cr/data-p.    ●─────────────────── (PR #33, 停滞) ⚠️ 需处理
cr/cloudwatch ●─────────────────── (PR #32, 停滞) ⚠️ 需处理
```

---

## 🎯 推荐策略：简化 Git Flow

```
main (生产, 受保护)
  ↑
  │ 定期合并 (每周/双周)
  │
dev (开发集成)
  ↑
  ├── feature/功能A
  ├── feature/功能B
  └── feature/功能C
```

---

## ✅ 立即行动（今天）

### 1. 合并 optimize-single-user
```bash
# 在 GitHub 上合并 PR #46
# 或命令行:
git checkout main
git merge optimize-single-user
git push origin main
git branch -D optimize-single-user
git push origin --delete optimize-single-user
```

### 2. 清理停滞的 PR
```bash
gh pr close 32 -c "Closing stale PR"
gh pr close 33 -c "Closing stale PR"
git push origin --delete cr/data-protection
git push origin --delete cr/cloudwatch-alarms
```

### 3. 同步 dev
```bash
git checkout dev
git merge main
git push origin dev
```

### 4. 设置分支保护
```
GitHub → Settings → Branches → Add rule
Branch: main
✅ Require pull request before merging
✅ Require approvals (1)
```

---

## 🚀 日常开发流程

### 新功能开发
```bash
# 1. 创建功能分支
git checkout dev
git pull
git checkout -b feature/my-feature

# 2. 开发
# ... 编码 ...
git add .
git commit -m "feat: add my feature"
git push origin feature/my-feature

# 3. 创建 PR (feature → dev)
gh pr create --base dev

# 4. 合并后删除分支
git branch -d feature/my-feature
git push origin --delete feature/my-feature
```

### 发布到生产
```bash
# 定期（如每周）
git checkout main
git merge --no-ff dev -m "release: v1.x.0"
git tag v1.x.0
git push origin main --tags
```

---

## 📏 分支命名规范

| 类型 | 格式 | 示例 |
|------|------|------|
| 功能 | `feature/描述` | `feature/single-user-optimization` |
| 修复 | `fix/描述` | `fix/guardduty-conflict` |
| 热修复 | `hotfix/描述` | `hotfix/security-patch` |
| 文档 | `docs/描述` | `docs/update-readme` |

---

## 🎯 分支职责

| 分支 | 用途 | 稳定性 | 部署 | 保护 |
|------|------|--------|------|------|
| **main** | 生产代码 | ✅ 稳定 | 生产环境 | 🔒 完全保护 |
| **dev** | 开发集成 | ⚠️ 测试中 | 测试环境 | ⚠️ 可选保护 |
| **feature/*** | 功能开发 | ❌ 开发中 | 本地 | ❌ 无保护 |

---

## 💡 提交信息规范

```bash
feat: add new feature       ✅
fix: resolve bug            ✅
docs: update README         ✅
chore: update deps          ✅
refactor: improve code      ✅

update                      ❌ 太模糊
fix bug                     ❌ 不够具体
Added new feature           ❌ 不够标准
```

---

## 📊 实施前后对比

### 实施前 ❌
```
● 5个分支混乱
● 2个停滞的 PR
● 无分支保护
● 无清晰流程
```

### 实施后 ✅
```
● 2个主要分支 (main, dev)
● 功能分支按需创建/删除
● main 受保护
● 清晰的开发→集成→发布流程
```

---

## 🔗 相关文档

- 详细策略：`docs/BRANCHING_STRATEGY.md`
- 贡献指南：`CONTRIBUTING.md` (待创建)
- 发布流程：`docs/RELEASE_PROCESS.md` (待创建)

---

**预计时间:** 1-2 小时完成清理  
**难度:** ⭐ 简单  
**团队规模:** 适合 2-5 人小团队  

---

*保持简单，持续改进！* 🚀
