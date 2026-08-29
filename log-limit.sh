#!/bin/bash

set -e

echo "======================================"
echo " Docker + systemd 日志限制工具"
echo " systemd : 10MB"
echo " Docker  : 10MB × 1"
echo "======================================"

# ======================================
# 1. systemd journal
# ======================================

echo
echo "[1/4] 设置 systemd 日志限制..."

mkdir -p /etc/systemd/journald.conf.d

cat > /etc/systemd/journald.conf.d/size.conf <<'EOF'
[Journal]
SystemMaxUse=10M
RuntimeMaxUse=10M
EOF

systemctl restart systemd-journald

# 立即清理旧日志
journalctl --vacuum-size=10M


# ======================================
# 2. Docker daemon.json
# ======================================

echo
echo "[2/4] 设置 Docker 日志限制..."

mkdir -p /etc/docker

CONFIG="/etc/docker/daemon.json"

# 如果已经存在，先备份
if [ -f "$CONFIG" ]; then
    BACKUP="${CONFIG}.backup.$(date +%Y%m%d_%H%M%S)"
    cp "$CONFIG" "$BACKUP"
    echo "已备份原配置：$BACKUP"
fi

# 使用 Python 合并配置
python3 <<'PY'
import json
import os

config = "/etc/docker/daemon.json"

try:
    if os.path.exists(config) and os.path.getsize(config) > 0:
        with open(config, "r") as f:
            data = json.load(f)
    else:
        data = {}
except Exception as e:
    print("无法读取现有 daemon.json：", e)
    print("请检查配置文件后再执行。")
    raise SystemExit(1)

data["log-driver"] = "json-file"

log_opts = data.get("log-opts", {})
if not isinstance(log_opts, dict):
    log_opts = {}

log_opts["max-size"] = "10m"
log_opts["max-file"] = "1"

data["log-opts"] = log_opts

with open(config, "w") as f:
    json.dump(data, f, indent=2)
    f.write("\n")

print("Docker 日志策略已设置：10MB × 1")
PY


# ======================================
# 3. 重启 Docker
# ======================================

echo
echo "[3/4] 重启 Docker..."

systemctl restart docker

echo "Docker 重启成功。"


# ======================================
# 4. 清理旧 Docker 日志
# ======================================

echo
echo "[4/4] 清理现有 Docker 日志..."

if [ -d /var/lib/docker/containers ]; then

    find /var/lib/docker/containers/ \
        -type f \
        -name "*-json.log" \
        -exec truncate -s 0 {} \;

fi

echo
echo "======================================"
echo " 设置完成"
echo "======================================"

echo
echo "systemd 日志："
journalctl --disk-usage

echo
echo "Docker 日志驱动："
docker info 2>/dev/null | grep "Logging Driver" || true

echo
echo "Docker 配置："
cat /etc/docker/daemon.json

echo
echo "======================================"
echo " 注意"
echo "======================================"
echo "新创建的 Docker 容器：10MB × 1"
echo "现有容器已清空当前日志。"
echo "现有容器的日志配置是否立即改变，取决于其创建时的配置。"
echo "======================================"
