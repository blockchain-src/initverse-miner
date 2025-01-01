#!/bin/bash

# 确保以 root 权限运行
if [ "$(id -u)" -ne 0 ]; then
    echo "请使用 root 权限运行此脚本（例如使用 sudo）。"
    exit 1
fi

# 更新系统
echo "更新系统中..."
apt update && apt upgrade -y

# 安装 Node.js 18.x
echo "安装 Node.js 18.x 中..."
curl -fsSL https://deb.nodesource.com/setup_18.x | bash -
apt install nodejs -y

# 安装 pm2
echo "安装 pm2 中..."
npm install -g pm2

# 验证安装
echo "验证安装..."
node -v && npm -v && pm2 --version

echo "所有操作完成！"
