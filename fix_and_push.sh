#!/bin/bash

# 修复版GitHub推送脚本
echo "开始修复并推送NetSignal项目到GitHub..."

# 进入项目目录
cd /Users/jesse./Documents/Trae/NetSignal

# 添加所有文件（包括新文件和修改的文件）
echo "添加所有文件..."
git add .

# 提交所有更改
echo "提交更改..."
git commit -m "feat: 完善项目结构和文件"

# 配置凭证存储
echo "配置凭证存储..."
git config --global credential.helper store

# 显示当前状态
echo "当前Git状态:"
git status

# 显示远程仓库配置
echo "远程仓库配置:"
git remote -v

# 尝试推送（这会触发认证提示）
echo "正在推送代码到GitHub..."
git push -u origin main

echo "推送完成！"