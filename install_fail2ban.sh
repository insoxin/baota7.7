#!/bin/bash

# 1. 安装 Fail2ban
echo "正在安装 Fail2ban..."
sudo apt install fail2ban -y

# 2. 备份并创建 jail.local
echo "正在配置 jail.local..."
sudo cp /etc/fail2ban/jail.conf /etc/fail2ban/jail.local

# 3. 写入推荐配置
# 注意：这里默认 SSH 端口为 22 (port = ssh)。如果你的端口改了，Fail2ban 通常能自动识别 'ssh' 别名，
# 但如果识别失败，请手动修改生成的 /etc/fail2ban/jail.local 文件。

sudo tee /etc/fail2ban/jail.local > /dev/null <<EOF
[DEFAULT]
# 白名单：本地回环
ignoreip = 127.0.0.1/8 ::1

# 基础封禁时间：1小时
bantime = 1h
# 统计时间窗口：10分钟
findtime = 10m
# 允许错误次数：3次
maxretry = 3

# --- 开启递增封禁 (越封越久) ---
bantime.increment = true
bantime.factor = 1
bantime.maxtime = 5w

[sshd]
enabled = true
port    = ssh
mode    = aggressive
logpath = %(sshd_log)s
backend = %(sshd_backend)s

[recidive]
# 针对顽固分子的长效监狱
enabled  = true
logpath  = /var/log/fail2ban.log
banaction = %(banaction_allports)s
bantime  = 1w
findtime = 1d
maxretry = 5
EOF

# 4. 重启服务
echo "正在重启服务..."
sudo systemctl enable fail2ban
sudo systemctl restart fail2ban

echo "==========================================="
echo "Fail2ban 安装并配置完成！"
echo "检查状态命令: sudo fail2ban-client status sshd"
echo "==========================================="

