#!/bin/bash
# =============================================================================
# bt-panel-ip-ssl.sh
# 用 acme.sh 为「宝塔面板后台」申请 Let's Encrypt 纯 IPv4 证书并自动启用/续期
#
#   适用: 宝塔 Linux 面板 7.x（无域名、仅公网 IP、80 被 nginx 占用、不要自签）
#   用法: bash bt-panel-ip-ssl.sh              # 自动探测公网 IPv4
#         bash bt-panel-ip-ssl.sh 1.2.3.4      # 手动指定 IP
#         EMAIL=you@mail.com bash bt-panel-ip-ssl.sh
#         TOGGLE444=1 bash bt-panel-ip-ssl.sh  # 强制用「临时注释 return 444」方案
#         bash bt-panel-ip-ssl.sh --revert     # 一键回滚（关面板 SSL、还原旧证书）
#
#   说明: Let's Encrypt 的 IP 证书只能用 shortlived profile，有效期约 6.7 天，
#         所以必须依赖 acme.sh 的每日 cron 自动续期（本脚本按 3 天续一次）。
# =============================================================================
set -o pipefail

PANEL_DIR=/www/server/panel
SSL_DIR="$PANEL_DIR/ssl"
NGX_VHOST=/www/server/panel/vhost/nginx
ACME_VHOST="$NGX_VHOST/0.acme-challenge-ip.conf"   # 文件名以 0. 开头，保证先于其它站点被 include
WEBROOT=/www/tool/acmesh/webroot
ACME=/root/.acme.sh/acme.sh
RENEW_DAYS=3
EMAIL="${EMAIL:-}"
FORCE="${FORCE:-0}"

RED=$'\033[31m'; GRN=$'\033[32m'; YLW=$'\033[33m'; BLU=$'\033[36m'; NC=$'\033[0m'
step(){ echo; echo "${BLU}==>${NC} $*"; }
info(){ echo "  ${GRN}✓${NC} $*"; }
warn(){ echo "  ${YLW}!${NC} $*"; }
die(){  echo; echo "${RED}✗ $*${NC}" >&2; exit 1; }

# ---------------------------------------------------------------- 0. 前置检查
[ "$(id -u)" = 0 ] || die "请用 root 运行"
[ -d "$PANEL_DIR" ] || die "未检测到宝塔面板（$PANEL_DIR 不存在）"
command -v curl >/dev/null || die "缺少 curl，请先安装"

PANEL_PORT=$(tr -dc '0-9' < "$PANEL_DIR/data/port.pl" 2>/dev/null); PANEL_PORT=${PANEL_PORT:-8888}
ADMIN_PATH=$(tr -d '[:space:]' < "$PANEL_DIR/data/admin_path.pl" 2>/dev/null)
BOUND_DOMAIN=$(tr -d '[:space:]' < "$PANEL_DIR/data/domain.conf" 2>/dev/null)

nginx_reload(){
    if nginx -t >/dev/null 2>&1; then
        nginx -s reload >/dev/null 2>&1 || /etc/init.d/nginx reload >/dev/null 2>&1
        sleep 2   # 等旧 worker 退完，否则紧接着发的请求可能还落在旧配置上
        return 0
    fi
    return 1
}

# ---------------------------------------------------------------- 回滚模式
if [ "$1" = "--revert" ] || [ "$1" = "revert" ]; then
    step "回滚：关闭面板 SSL 并还原原证书"
    LAST_BK=$(ls -1d "$SSL_DIR"/backup_* 2>/dev/null | tail -1)
    rm -f "$PANEL_DIR/data/ssl.pl"
    if [ -n "$LAST_BK" ]; then
        cp -a "$LAST_BK/certificate.pem" "$SSL_DIR/certificate.pem" 2>/dev/null
        cp -a "$LAST_BK/privateKey.pem"  "$SSL_DIR/privateKey.pem"  2>/dev/null
        info "已从 $LAST_BK 还原"
    fi
    [ -f "$ACME_VHOST" ] && { rm -f "$ACME_VHOST"; nginx_reload && info "已移除 nginx 验证配置"; }
    [ -x /www/tool/acmesh/acme-444-toggle.sh ] && bash /www/tool/acmesh/acme-444-toggle.sh on
    rm -f /www/server/panel/vhost/nginx/extension/*/00-acme-challenge.conf 2>/dev/null
    nginx_reload
    [ -x "$ACME" ] && "$ACME" --list 2>/dev/null | awk 'NR>1{print $1}' | \
        grep -E '^([0-9]{1,3}\.){3}[0-9]{1,3}$' | while read -r d; do "$ACME" --remove -d "$d" >/dev/null 2>&1; done
    /etc/init.d/bt restart >/dev/null 2>&1
    echo; echo "${GRN}已回滚，面板恢复 http://<IP>:$PANEL_PORT$ADMIN_PATH${NC}"
    exit 0
fi

# ---------------------------------------------------------------- 1. 确定公网 IPv4
step "确定公网 IPv4"
IP="$1"
if [ -z "$IP" ]; then
    for u in https://api.ipify.org https://ipv4.icanhazip.com https://ifconfig.me/ip https://4.ipw.cn; do
        IP=$(curl -4fsS --max-time 8 "$u" 2>/dev/null | tr -d '[:space:]')
        [[ "$IP" =~ ^([0-9]{1,3}\.){3}[0-9]{1,3}$ ]] && break || IP=""
    done
fi
[[ "$IP" =~ ^([0-9]{1,3}\.){3}[0-9]{1,3}$ ]] || die "无法确定公网 IPv4，请手动指定：bash $0 <公网IP>"
case "$IP" in
    10.*|127.*|0.*|169.254.*|192.168.*|172.1[6-9].*|172.2[0-9].*|172.3[01].*|100.6[4-9].*|100.[7-9][0-9].*|100.1[0-1][0-9].*|100.12[0-7].*)
        die "$IP 是内网/保留地址，CA 不会为其签发证书" ;;
esac
info "目标 IP: $IP    面板端口: $PANEL_PORT    安全入口: ${ADMIN_PATH:-（未设置）}"
[ -n "$BOUND_DOMAIN" ] && warn "面板已绑定域名 $BOUND_DOMAIN，用 IP 访问会被面板拒绝，请先在面板里解绑"

# ---------------------------------------------------------------- 2. 安装 acme.sh
step "安装 / 更新 acme.sh"
if [ ! -x "$ACME" ]; then
    if [ -n "$EMAIL" ]; then curl -fsS https://get.acme.sh | sh -s email="$EMAIL"
    else                     curl -fsS https://get.acme.sh | sh; fi
fi
[ -x "$ACME" ] || die "acme.sh 安装失败，检查服务器到 github 的网络"
"$ACME" --upgrade --auto-upgrade >/dev/null 2>&1
"$ACME" --set-default-ca --server letsencrypt >/dev/null 2>&1 || die "切换默认 CA 到 Let's Encrypt 失败"
info "acme.sh $("$ACME" --version 2>/dev/null | tail -1)，默认 CA 已设为 Let's Encrypt"

# 确认当前版本支持 profile 参数（IP 证书必需）
if   "$ACME" --help 2>&1 | grep -q -- '--cert-profile';        then PROFILE_FLAG=--cert-profile
elif "$ACME" --help 2>&1 | grep -q -- '--certificate-profile'; then PROFILE_FLAG=--certificate-profile
else die "acme.sh 版本过旧，不支持证书 profile。请执行 $ACME --upgrade 后重试"
fi
info "profile 参数: $PROFILE_FLAG shortlived"

# ---------------------------------------------------------------- 3. 准备 http-01 验证通道
# IP 证书只支持 http-01 / tls-alpn-01。443 常被其它服务占用，这里统一走 80 端口 http-01。
step "准备 80 端口 http-01 验证通道"
mkdir -p "$WEBROOT/.well-known/acme-challenge" || die "无法创建 $WEBROOT"
chmod -R 755 "$WEBROOT"

PORT80_PROC=$(ss -tlnp 2>/dev/null | awk '$4 ~ /:80$/ {print $NF; exit}')
MODE=webroot
if [ -z "$PORT80_PROC" ]; then
    MODE=standalone
    warn "80 端口空闲，使用 acme.sh standalone 模式"
elif echo "$PORT80_PROC" | grep -q nginx; then
    # 用「server_name = 该 IP」的独立 server 块接管对 IP 的裸访问。
    # nginx 对重复 server_name 取配置里最先出现的一个，本文件名以 0. 开头，
    # 因此即使某个站点的 server_name 里也写了这个 IP，验证请求也会落到这里。
    cat > "$ACME_VHOST" <<EOF
# 由 bt-panel-ip-ssl.sh 生成，仅用于 acme.sh 的 IP 证书 http-01 验证，勿在面板里编辑
server {
    listen 80;
    server_name $IP;
    access_log off;

    location ^~ /.well-known/acme-challenge/ {
        root $WEBROOT;
        default_type text/plain;
        try_files \$uri =404;
    }

    location / { return 444; }
}
EOF
    if ! nginx -t >/dev/null 2>&1; then
        nginx -t 2>&1 | tail -5
        rm -f "$ACME_VHOST"
        die "写入 nginx 验证配置后 nginx -t 失败，已自动删除该文件，nginx 配置未被破坏"
    fi
    nginx_reload || die "nginx reload 失败"
    info "已写入 $ACME_VHOST 并 reload nginx"
    info "若 nginx 报 'conflicting server name ... ignored' 属正常：说明已有站点也写了这个 IP，"
    echo "    本文件排在前面，验证请求会优先落到这里，原站点其它域名不受影响。"
else
    die "80 端口被非 nginx 进程占用（$PORT80_PROC）。请手动把 http://$IP/.well-known/acme-challenge/ 指向 $WEBROOT 后重跑"
fi

# 预检：真实走一遍公网，确认 CA 能读到验证文件（可提前发现防火墙 / WAF / 安全组 / 抢占问题）
TOGGLE=/www/tool/acmesh/acme-444-toggle.sh
USE_TOGGLE=0
preflight(){
    local token got i
    token="preflight-$(date +%s)-$RANDOM"
    echo "$token" > "$WEBROOT/.well-known/acme-challenge/$token"
    # 重试若干次：reload 后旧 worker 可能还在服务，一次失败不代表配置错了
    for i in 1 2 3 4; do
        got=$(curl -4fsS --max-time 12 "http://$IP/.well-known/acme-challenge/$token" 2>/dev/null | tr -d '[:space:]')
        [ "$got" = "$token" ] && break
        sleep 2
    done
    rm -f "$WEBROOT/.well-known/acme-challenge/$token"
    [ "$got" = "$token" ]
}
PREFLIGHT_FAIL_MSG="预检失败：从公网读取 http://$IP/.well-known/acme-challenge/ 未拿到预期内容。
     请检查：云厂商安全组 / 宝塔防火墙是否放行 TCP 80、宝塔 WAF 是否拦截、
     以及 nginx.conf 里是否有更早加载的 server 块抢走了这个 IP。
     排查完重跑本脚本即可（配置已就位，不会重复写）。"

if [ "$MODE" = webroot ]; then
    if [ "${TOGGLE444:-0}" = 1 ] && [ -x "$TOGGLE" ]; then
        warn "TOGGLE444=1，直接使用「临时注释 return 444」方案"
        USE_TOGGLE=1; bash "$TOGGLE" off "$IP"
    fi
    if preflight; then
        info "公网预检通过$([ "$USE_TOGGLE" = 1 ] && echo "（临时放通模式）")"
    elif [ "$USE_TOGGLE" = 0 ] && [ -x "$TOGGLE" ] && grep -rl 'return 444;' "$NGX_VHOST"/*.conf >/dev/null 2>&1; then
        # 说明有更早加载的 server 块接管了这个 IP 并且直接 return 444，退化到临时放通方案
        warn "预检未通过，且检测到站点配置里有 return 444;，自动切换到「临时注释 return 444」方案重试"
        USE_TOGGLE=1; bash "$TOGGLE" off "$IP"
        preflight && info "公网预检通过（临时放通模式）" || { bash "$TOGGLE" on; die "$PREFLIGHT_FAIL_MSG"; }
    else
        [ "$USE_TOGGLE" = 1 ] && bash "$TOGGLE" on
        die "$PREFLIGHT_FAIL_MSG"
    fi
fi

# ---------------------------------------------------------------- 4. 申请证书
step "向 Let's Encrypt 申请 IP 证书（shortlived profile）"
ISSUE_ARGS=(--issue --server letsencrypt -d "$IP" "$PROFILE_FLAG" shortlived
            --keylength 2048 --days "$RENEW_DAYS")   # RSA2048：宝塔面板 gunicorn 的 ciphers 配置对 RSA 兼容性最好
[ "$MODE" = standalone ] && ISSUE_ARGS+=(--standalone) || ISSUE_ARGS+=(-w "$WEBROOT")
[ -n "$EMAIL" ] && ISSUE_ARGS+=(--accountemail "$EMAIL")
[ "$FORCE" = 1 ] && ISSUE_ARGS+=(--force)
# 临时放通模式：把开/关 444 挂到 acme.sh 钩子上，这样每次自动续期也能自己开关
if [ "$USE_TOGGLE" = 1 ]; then
    ISSUE_ARGS+=(--pre-hook "bash $TOGGLE off $IP" --post-hook "bash $TOGGLE on")
    warn "本机使用临时放通模式：每次续期会有约 10~20 秒窗口，裸 IP 不再返回 444"
fi

if ! "$ACME" "${ISSUE_ARGS[@]}"; then
    ISSUE_FAILED=1
    "$ACME" --list 2>/dev/null | grep -q "^$IP" \
        && warn "签发命令返回非 0，但本地已有该 IP 的证书记录，继续尝试安装" \
        || { [ "$USE_TOGGLE" = 1 ] && bash "$TOGGLE" on
             die "证书申请失败，请看上面 acme.sh 的输出。若提示 profile 不存在，执行 $ACME --list-profiles --server letsencrypt 查看可用 profile"; }
fi
[ "$USE_TOGGLE" = 1 ] && bash "$TOGGLE" on   # 兜底还原，post-hook 已经做过则为空操作
CERT_SRC="/root/.acme.sh/$IP/fullchain.cer"
[ -s "$CERT_SRC" ] || die "未找到签发结果 $CERT_SRC"
info "签发成功：$CERT_SRC"

# ---------------------------------------------------------------- 5. 装到面板并开启 SSL
step "安装证书到宝塔面板并开启后台 SSL"
TS=$(date +%Y%m%d%H%M%S)
BK="$SSL_DIR/backup_$TS"
mkdir -p "$BK"
cp -a "$SSL_DIR/certificate.pem" "$BK/" 2>/dev/null
cp -a "$SSL_DIR/privateKey.pem"  "$BK/" 2>/dev/null
info "原证书已备份到 $BK"

# --reloadcmd 会在每次自动续期后执行，负责修权限 + 重启面板让新证书生效
RELOADCMD="chmod 600 '$SSL_DIR/certificate.pem' '$SSL_DIR/privateKey.pem'; /etc/init.d/bt restart"
"$ACME" --install-cert -d "$IP" \
        --key-file       "$SSL_DIR/privateKey.pem" \
        --fullchain-file "$SSL_DIR/certificate.pem" \
        --reloadcmd      "$RELOADCMD" || die "install-cert 失败"

printf 'True' > "$PANEL_DIR/data/ssl.pl"          # 宝塔以该文件是否存在决定面板走 https
chmod 600 "$SSL_DIR/certificate.pem" "$SSL_DIR/privateKey.pem"
/etc/init.d/bt restart >/dev/null 2>&1
info "已开启面板 SSL 并重启面板"

# 保证 acme.sh 的每日续期 cron 存在（IP 证书只有 ~6.7 天，缺了 cron 必过期）
if ! crontab -l 2>/dev/null | grep -q 'acme.sh'; then
    "$ACME" --install-cronjob >/dev/null 2>&1
fi
crontab -l 2>/dev/null | grep -q 'acme.sh' && info "自动续期 cron 已就位（每日检查，满 $RENEW_DAYS 天即续）" \
                                          || warn "未检测到 acme.sh cron，请手动执行 $ACME --install-cronjob"

# ---------------------------------------------------------------- 6. 校验，失败自动回滚
# 注意：开了安全入口后 /login 会返回 404，状态码不可靠，
# 这里只判断「TLS 握手能不能成」——curl 拿不到响应时 %{http_code} 是 000。
step "校验面板 HTTPS"
CODE=000
for i in $(seq 1 15); do
    CODE=$(curl -k -s -o /dev/null -w '%{http_code}' --max-time 5 "https://127.0.0.1:$PANEL_PORT/" 2>/dev/null)
    [ -n "$CODE" ] && [ "$CODE" != 000 ] && break
    sleep 2
done
if [ -z "$CODE" ] || [ "$CODE" = 000 ]; then
    warn "面板 HTTPS 握手失败，自动回滚以免锁死后台…"
    rm -f "$PANEL_DIR/data/ssl.pl"
    cp -a "$BK/certificate.pem" "$SSL_DIR/certificate.pem" 2>/dev/null
    cp -a "$BK/privateKey.pem"  "$SSL_DIR/privateKey.pem"  2>/dev/null
    /etc/init.d/bt restart >/dev/null 2>&1
    die "已回滚到 http 访问。证书本身已签发在 /root/.acme.sh/$IP/，可查看 $PANEL_DIR/logs/error.log 定位原因"
fi
info "面板 HTTPS 握手正常（GET / 返回 HTTP $CODE）"

# 确认面板真的在用这张 IP 证书
if echo | timeout 8 openssl s_client -connect "127.0.0.1:$PANEL_PORT" 2>/dev/null | \
   openssl x509 -noout -text 2>/dev/null | grep -q "IP Address:$IP"; then
    info "面板已加载该 IP 证书"
else
    warn "未能从 TLS 握手中确认证书内容（不一定是故障，可用浏览器复核）"
fi

SAN=$(openssl x509 -in "$SSL_DIR/certificate.pem" -noout -text 2>/dev/null | grep -A1 'Subject Alternative Name' | tail -1 | tr -d ' ')
NOT_AFTER=$(openssl x509 -in "$SSL_DIR/certificate.pem" -noout -enddate 2>/dev/null | cut -d= -f2)
ISSUER=$(openssl x509 -in "$SSL_DIR/certificate.pem" -noout -issuer 2>/dev/null | sed 's/.*CN *= *//')
info "SAN: ${SAN:-未知}"
info "颁发者: ${ISSUER:-未知}    到期: ${NOT_AFTER:-未知}"

# ---------------------------------------------------------------- 完成
if [ "$USE_TOGGLE" = 1 ]; then
    TOGGLE_NOTE=" · 验证方式  续期时由钩子临时注释 return 444;（$TOGGLE），完成后自动加回"
else
    TOGGLE_NOTE=" · 验证方式  独立 server 块接管裸 IP，你的 return 444; 全程没有被改动"
fi

cat <<EOF

${GRN}────────────────────────────────────────────────────────${NC}
${GRN} 完成${NC}  后台地址: ${BLU}https://$IP:$PANEL_PORT$ADMIN_PATH${NC}

 · 证书类型  Let's Encrypt IP 证书（shortlived，有效期约 6.7 天）
 · 自动续期  acme.sh 每日 cron 检查，满 $RENEW_DAYS 天续期一次，
             续期后自动 chmod 并 /etc/init.d/bt restart（面板会短暂重启几秒）
$TOGGLE_NOTE
 · 续期前提  TCP 80 必须长期放行，且 $ACME_VHOST 不要删
 · 手动验证  $ACME --renew -d $IP --force
 · 一键回滚  bash $0 --revert
 · 紧急恢复  rm -f $PANEL_DIR/data/ssl.pl && /etc/init.d/bt restart
${GRN}────────────────────────────────────────────────────────${NC}
EOF

