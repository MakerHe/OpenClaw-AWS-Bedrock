#!/bin/bash
# PR 清理和合并脚本
# 用途: 执行 PR #46 合并和 #33, #32 清理

set -e

echo "=== OpenClaw AWS Bedrock - PR 管理脚本 ==="
echo ""
echo "当前时间: $(date -u '+%Y-%m-%d %H:%M:%S UTC')"
echo ""

# 检查 gh CLI
if ! command -v gh &> /dev/null; then
    echo "❌ GitHub CLI (gh) 未安装"
    echo "安装: https://cli.github.com/"
    exit 1
fi

echo "✅ GitHub CLI 已安装"
echo ""

# 选择操作
echo "请选择操作:"
echo "1) 合并 PR #46 (optimize-single-user)"
echo "2) 通知 PR #33 和 #32 作者（礼貌等待 7 天）"
echo "3) 关闭 PR #33 和 #32（直接清理）"
echo "4) 执行全部（合并 #46 + 通知 #33/#32）"
echo "5) 仅查看 PR 状态（不做更改）"
echo ""
read -p "选择 (1-5): " choice

case $choice in
    1)
        echo ""
        echo "=== 合并 PR #46 ==="
        echo ""
        
        echo "1. 审查 PR #46..."
        gh pr view 46
        echo ""
        
        read -p "确认合并? (y/N): " confirm
        if [ "$confirm" != "y" ]; then
            echo "已取消"
            exit 0
        fi
        
        echo ""
        echo "2. 审批 PR..."
        gh pr review 46 --approve -b "LGTM! Excellent documentation and tooling improvements. Tested and ready to merge."
        
        echo ""
        echo "3. 合并 PR (squash and merge)..."
        gh pr merge 46 --squash --delete-branch
        
        echo ""
        echo "✅ PR #46 已合并并删除分支"
        ;;
        
    2)
        echo ""
        echo "=== 通知 PR #33 和 #32 ==="
        echo ""
        
        MESSAGE="Hi @gustavocabral,

This PR looks interesting but appears stale:
- Last updated: 7+ days ago
- Branch has been deleted from the repository

If you'd still like to contribute this feature, could you please:
1. Recreate the branch based on current \`main\`
2. Rebase/update the implementation if needed
3. Respond within 7 days

Otherwise, I'll close this PR to keep the list clean. You're always welcome to reopen or create a new PR if needed later.

Thanks for your contribution!"

        echo "消息内容:"
        echo "---"
        echo "$MESSAGE"
        echo "---"
        echo ""
        
        read -p "发送通知到 PR #33 和 #32? (y/N): " confirm
        if [ "$confirm" != "y" ]; then
            echo "已取消"
            exit 0
        fi
        
        echo ""
        echo "发送到 PR #33..."
        gh pr comment 33 -b "$MESSAGE"
        
        echo ""
        echo "发送到 PR #32..."
        gh pr comment 32 -b "$MESSAGE"
        
        echo ""
        echo "✅ 通知已发送到 PR #33 和 #32"
        echo "⏰ 7 天后检查响应"
        ;;
        
    3)
        echo ""
        echo "=== 关闭 PR #33 和 #32 ==="
        echo ""
        
        CLOSE_MESSAGE="Closing stale PR:
- Branch has been deleted
- No activity for 7+ days
- No response to previous notification

Feel free to reopen with an updated branch if this feature is still relevant. Thanks!"

        echo "关闭消息:"
        echo "---"
        echo "$CLOSE_MESSAGE"
        echo "---"
        echo ""
        
        read -p "确认关闭 PR #33 和 #32? (y/N): " confirm
        if [ "$confirm" != "y" ]; then
            echo "已取消"
            exit 0
        fi
        
        echo ""
        echo "关闭 PR #33..."
        gh pr close 33 -c "$CLOSE_MESSAGE"
        
        echo ""
        echo "关闭 PR #32..."
        gh pr close 32 -c "$CLOSE_MESSAGE"
        
        echo ""
        echo "✅ PR #33 和 #32 已关闭"
        ;;
        
    4)
        echo ""
        echo "=== 执行全部操作 ==="
        echo ""
        
        # 合并 PR #46
        echo "步骤 1/2: 合并 PR #46"
        echo ""
        gh pr view 46
        echo ""
        
        read -p "确认合并 PR #46? (y/N): " confirm
        if [ "$confirm" == "y" ]; then
            gh pr review 46 --approve -b "LGTM! Excellent improvements."
            gh pr merge 46 --squash --delete-branch
            echo "✅ PR #46 已合并"
        else
            echo "⏭️  跳过 PR #46"
        fi
        
        echo ""
        echo "步骤 2/2: 通知 PR #33 和 #32"
        echo ""
        
        read -p "发送通知到 PR #33 和 #32? (y/N): " confirm
        if [ "$confirm" == "y" ]; then
            MESSAGE="Hi @gustavocabral, This PR appears stale (7+ days, branch deleted). Please recreate and update within 7 days, or I'll close to keep the list clean. Thanks!"
            gh pr comment 33 -b "$MESSAGE"
            gh pr comment 32 -b "$MESSAGE"
            echo "✅ 通知已发送"
        else
            echo "⏭️  跳过通知"
        fi
        
        echo ""
        echo "✅ 全部操作完成"
        ;;
        
    5)
        echo ""
        echo "=== 当前 PR 状态 ==="
        echo ""
        gh pr list --state open
        echo ""
        echo "PR #46 详情:"
        gh pr view 46 --json number,title,author,createdAt,updatedAt,additions,deletions | \
          jq -r '"Title: \(.title)\nAuthor: \(.author.login)\nCreated: \(.createdAt)\nUpdated: \(.updatedAt)\nChanges: +\(.additions)/-\(.deletions)"'
        echo ""
        echo "PR #33 详情:"
        gh pr view 33 --json number,title,author,createdAt,updatedAt,additions,deletions | \
          jq -r '"Title: \(.title)\nAuthor: \(.author.login)\nCreated: \(.createdAt)\nUpdated: \(.updatedAt)\nChanges: +\(.additions)/-\(.deletions)"'
        echo ""
        echo "PR #32 详情:"
        gh pr view 32 --json number,title,author,createdAt,updatedAt,additions,deletions | \
          jq -r '"Title: \(.title)\nAuthor: \(.author.login)\nCreated: \(.createdAt)\nUpdated: \(.updatedAt)\nChanges: +\(.additions)/-\(.deletions)"'
        ;;
        
    *)
        echo "无效选择"
        exit 1
        ;;
esac

echo ""
echo "=== 完成 ==="
