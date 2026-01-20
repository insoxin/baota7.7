#!/bin/bash
set -e
# set -e: 遇到错误立即退出 (Fail Fast)，防止错误蔓延

# ==========================================
# Fail2ban 模块化一键安装脚本 insoxin
# ==========================================

# 1. 更新源并安装 Fail2ban
echo "正在更新源并安装 Fail2ban..."
sudo apt update && sudo apt install fail2ban -y

# 2. 清理旧的单文件配置 (如果存在)
if [ -f /etc/fail2ban/jail.local ]; then
    echo "发现旧的 jail.local，正在备份并移除以使用模块化配置..."
    sudo mv /etc/fail2ban/jail.local /etc/fail2ban/jail.local.bak
fi

# 3. 获取版本号并检查是否支持递增封禁
# 使用 server 命令获取，提取最后一列 ($NF)，并去除开头的 'v'
VERSION=$(fail2ban-server --version | awk '{print $NF}' | sed 's/^v//')
INCREMENT_CONFIG=""

if dpkg --compare-versions "$VERSION" "ge" "0.11"; then
    echo "✅ 检测到 Fail2ban 版本 ($VERSION) >= 0.11，启用递增封禁特性。"
    INCREMENT_CONFIG="
# --- 开启递增封禁 ---
bantime.increment = true
bantime.factor = 1
bantime.maxtime = 10w"
else
    echo "⚠️ 版本 ($VERSION) < 0.11，跳过递增封禁配置。"
fi

# 4. 确保配置目录存在 (防御性措施)
echo "正在检查并创建配置目录..."
sudo mkdir -p /etc/fail2ban/jail.d

# 5. 写入全局默认配置 (00-defaults.local)
echo "正在配置全局默认设置 (00-defaults.local)..."
sudo tee /etc/fail2ban/jail.d/00-defaults.local > /dev/null <<EOF
[DEFAULT]
# --- 白名单 (务必修改) ---
ignoreip = 127.0.0.1/8 ::1

# --- 基础封禁规则 ---
# 封禁 1 天
bantime = 1d
# 统计窗口 4 小时
findtime = 4h
# 允许错误 3 次
maxretry = 3

$INCREMENT_CONFIG
EOF

# 6. 写入 SSH 服务配置 (sshd.local)
echo "正在配置 SSH 监控 (sshd.local)..."
sudo tee /etc/fail2ban/jail.d/sshd.local > /dev/null <<EOF
[sshd]
enabled = true
port    = ssh
mode    = aggressive
logpath = %(sshd_log)s
backend = %(sshd_backend)s
EOF

# 7. 写入惯犯处理配置 (recidive.local)
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

# 8. 重启服务
echo "正在重启服务..."
sudo systemctl enable fail2ban
sudo systemctl restart fail2ban

echo "==========================================="
echo "Fail2ban 模块化配置安装完成！"
echo "当前安装版本: $VERSION"
echo "配置文件位置: /etc/fail2ban/jail.d/"
echo "检查状态命令: sudo fail2ban-client status"
echo "==========================================="
