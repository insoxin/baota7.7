#!/bin/bash

set -e

LOG_MAX_SIZE="10m"
LOG_MAX_FILE="1"

echo "======================================"
echo " Docker + systemd 日志限制工具（安全版）"
echo " systemd : 10MB"
echo " Docker  : ${LOG_MAX_SIZE} × ${LOG_MAX_FILE}"
echo "======================================"

echo
echo "[1/4] 设置 systemd 日志限制..."

mkdir -p /etc/systemd/journald.conf.d

cat > /etc/systemd/journald.conf.d/size.conf <<CONF
[Journal]
SystemMaxUse=10M
RuntimeMaxUse=10M
CONF

systemctl restart systemd-journald
journalctl --rotate
journalctl --vacuum-size=10M

echo "systemd 日志限制完成。"

echo
echo "[2/4] 设置 Docker 日志限制..."

mkdir -p /etc/docker

CONFIG="/etc/docker/daemon.json"

if [ -f "$CONFIG" ]; then
    BACKUP="${CONFIG}.backup.$(date +%Y%m%d_%H%M%S)"
    cp "$CONFIG" "$BACKUP"
    echo "已备份原配置：$BACKUP"
fi

python3 <<PY
import json, os

config = "/etc/docker/daemon.json"
try:
    if os.path.exists(config) and os.path.getsize(config) > 0:
        with open(config, "r") as f:
            data = json.load(f)
    else:
        data = {}
except Exception as e:
    print("无法读取现有 daemon.json：", e)
    raise SystemExit(1)

data["log-driver"] = "json-file"
log_opts = data.get("log-opts", {})
if not isinstance(log_opts, dict):
    log_opts = {}
log_opts["max-size"] = "${LOG_MAX_SIZE}"
log_opts["max-file"] = "${LOG_MAX_FILE}"
data["log-opts"] = log_opts

with open(config, "w") as f:
    json.dump(data, f, indent=2)
    f.write("\n")

print("Docker 日志策略已设置：${LOG_MAX_SIZE} × ${LOG_MAX_FILE}")
PY

echo
echo "[3/4] 重启 Docker..."

systemctl restart docker
sleep 2

echo "Docker 重启成功。"

echo
echo "[4/4] 逐个重启运行中的容器以重建日志管道..."

RUNNING=$(docker ps -q 2>/dev/null)

if [ -n "$RUNNING" ]; then
    for cid in $RUNNING; do
        name=$(docker inspect --format '{{.Name}}' "$cid" 2>/dev/null | sed 's|^/||')
        echo "  重启: $name"
        docker restart "$cid" >/dev/null 2>&1
        sleep 1
    done
    echo
    echo "所有运行中的容器已重启。"
else
    echo "没有运行中的容器，跳过。"
fi

echo
echo "清理已停止容器的旧日志..."

STOPPED=$(docker ps -aq --filter "status=exited" --filter "status=created" --filter "status=dead" 2>/dev/null)

if [ -n "$STOPPED" ]; then
    for cid in $STOPPED; do
        logfile="/var/lib/docker/containers/$cid/$cid-json.log"
        if [ -f "$logfile" ] && [ -s "$logfile" ]; then
            truncate -s 0 "$logfile"
            echo "  已清理: $cid"
        fi
    done
fi

echo
echo "======================================"
echo " 完成"
echo "======================================"
echo
echo "systemd 日志占用："
journalctl --disk-usage
echo
echo "Docker 日志驱动："
docker info 2>/dev/null | grep "Logging Driver" || true
echo
echo "Docker 配置："
cat /etc/docker/daemon.json
echo
echo "======================================"
echo " 说明"
echo "======================================"
echo " 1. 新创建的容器自动应用 ${LOG_MAX_SIZE} × ${LOG_MAX_FILE} 限制"
echo " 2. 已有容器的日志管道已通过重启修复"
echo " 3. 已有容器的 max-size 限制需要 docker rm 后重建才生效"
echo " 4. 历史日志已保留，不会被清空"
echo "======================================"
