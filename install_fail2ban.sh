#!/bin/bash
set -e
# set -e: 遇到错误立即退出

# ==========================================
# Fail2ban 模块化一键安装脚本 (insoxin
# ==========================================

# 1. 更新源并安装 Fail2ban
echo "正在更新源并安装 Fail2ban..."
sudo apt update && sudo apt install fail2ban -y

# 2. 清理旧的单文件配置
if [ -f /etc/fail2ban/jail.local ]; then
    echo "发现旧的 jail.local，正在备份并移除..."
    sudo mv /etc/fail2ban/jail.local /etc/fail2ban/jail.local.bak
fi

# 3. 版本检测 (递增封禁特性)
VERSION=$(fail2ban-server --version | awk '{print $NF}' | sed 's/^v//')
INCREMENT_CONFIG=""

if dpkg --compare-versions "$VERSION" "ge" "0.11"; then
    echo "✅ Fail2ban 版本 $VERSION 支持递增封禁。"
    INCREMENT_CONFIG="
# --- 开启递增封禁 ---
bantime.increment = true
bantime.factor = 1
bantime.maxtime = 10w"
else
    echo "⚠️ 版本 $VERSION 不支持递增封禁，跳过配置。"
fi

# 4. 【关键修复】智能检测 SSH 日志后端
# 如果找不到 /var/log/auth.log，说明是 Debian 12+，需要用 systemd 模式
SSH_BACKEND="%(sshd_backend)s"
if [ ! -f /var/log/auth.log ] && [ ! -f /var/log/secure ]; then
    echo "⚠️ 未检测到物理日志文件 (auth.log)，自动切换 SSH 后端为 'systemd'。"
    SSH_BACKEND="systemd"
else
    echo "✅ 检测到物理日志文件，使用默认后端。"
fi

# 5. 确保配置目录存在
sudo mkdir -p /etc/fail2ban/jail.d

# 6. 写入全局默认配置
echo "正在配置全局默认设置 (00-defaults.local)..."
sudo tee /etc/fail2ban/jail.d/00-defaults.local > /dev/null <<EOF
[DEFAULT]
# 白名单
ignoreip = 127.0.0.1/8 ::1

# 基础封禁规则
bantime = 1d
findtime = 4h
maxretry = 3

$INCREMENT_CONFIG
EOF

# 7. 写入 SSH 配置 (使用动态检测的后端)
echo "正在配置 SSH 监控 (sshd.local)..."
sudo tee /etc/fail2ban/jail.d/sshd.local > /dev/null <<EOF
[sshd]
enabled = true
port    = ssh
mode    = aggressive
# 这里使用了动态变量，如果是 Debian 12 会变成 'systemd'
backend = $SSH_BACKEND
# systemd 模式下不需要 logpath，但保留也无害(会被忽略)
logpath = %(sshd_log)s
EOF

# 8. 写入惯犯配置
echo "正在配置惯犯处理 (recidive.local)..."
sudo tee /etc/fail2ban/jail.d/recidive.local > /dev/null <<EOF
[recidive]
enabled  = true
logpath  = /var/log/fail2ban.log
banaction = %(banaction_allports)s
bantime  = 1y
findtime = 1w
maxretry = 5
EOF

# 9. 重启服务
echo "正在重启服务..."
sudo systemctl enable fail2ban
sudo systemctl restart fail2ban

echo "==========================================="
echo "Fail2ban 安装完成！"
echo "SSH 后端模式: $SSH_BACKEND"
echo "检查状态命令: sudo fail2ban-client status sshd"
echo "==========================================="
