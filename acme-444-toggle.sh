#!/bin/bash
# =============================================================================
# acme-444-toggle.sh —— 备用方案：临时注释 / 还原宝塔站点里的 return 444;
#
#   off <IP>   验证前：注释掉相关 conf 里的 return 444; 并放通 challenge 目录
#   on         验证后：把 return 444; 原样加回
#
#   用「标记注释」而不是删行，所以不依赖 return 444; 在文件里的位置，
#   多次执行也幂等；acme.sh 续期时由 --pre-hook / --post-hook 自动调用。
# =============================================================================
NGX_VHOST=/www/server/panel/vhost/nginx
WEBROOT=/www/tool/acmesh/webroot
MARK='#ACME444#'
GUARD_SEC=600           # 兜底：off 之后最多 600 秒自动还原，防止钩子异常导致 444 一直缺失

ACT="$1"; IP="$2"
log(){ echo "  [444-toggle] $*"; }

reload_ok(){ nginx -t >/dev/null 2>&1 && { nginx -s reload >/dev/null 2>&1 || /etc/init.d/nginx reload >/dev/null 2>&1; sleep 2; }; }
uncomment_all(){ grep -rl -- "$MARK" "$NGX_VHOST"/*.conf 2>/dev/null | while read -r f; do sed -i "s|$MARK||g" "$f"; done; }

case "$ACT" in
  off)
    [ -n "$IP" ] || { echo "用法: $0 off <IP>"; exit 1; }
    HIT=0
    for f in "$NGX_VHOST"/*.conf; do
        [ "$(basename "$f")" = "0.acme-challenge-ip.conf" ] && continue   # 跳过本方案自己生成的配置
        grep -q 'return 444;' "$f" 2>/dev/null || continue
        # 只处理「会接管裸 IP 访问」的那些：server_name 里写了该 IP，或者是 default_server
        grep -qE "server_name[^;]*(\<${IP//./\\.}\>)" "$f" || grep -q 'default_server' "$f" || continue

        site=$(basename "$f" .conf)
        if grep -q "extension/$site/" "$f"; then
            mkdir -p "$NGX_VHOST/extension/$site"
            cat > "$NGX_VHOST/extension/$site/00-acme-challenge.conf" <<EOF
# 由 acme-444-toggle.sh 生成：只放通 ACME 验证目录，长期留着不影响安全
location ^~ /.well-known/acme-challenge/ {
    root $WEBROOT;
    default_type text/plain;
    try_files \$uri =404;
}
EOF
        else
            log "警告：$site 没有 extension include，无法注入验证 location"
        fi

        sed -i "s|^\([[:space:]]*\)return 444;|\1${MARK}return 444;|" "$f"
        log "已临时注释 $(basename "$f") 里的 return 444;"
        HIT=1
    done
    [ "$HIT" = 1 ] || { log "没找到需要处理的 return 444;"; exit 0; }

    if ! reload_ok; then
        uncomment_all; nginx -t >/dev/null 2>&1 && reload_ok
        log "nginx 校验失败，已全部还原"; exit 1
    fi
    ( sleep "$GUARD_SEC"; grep -rlq -- "$MARK" "$NGX_VHOST"/*.conf 2>/dev/null && \
      { uncomment_all; reload_ok; } ) >/dev/null 2>&1 &
    log "已放通，${GUARD_SEC}s 后若未还原会自动还原"
    ;;
  on)
    grep -rl -- "$MARK" "$NGX_VHOST"/*.conf >/dev/null 2>&1 || { log "无需还原"; exit 0; }
    uncomment_all
    reload_ok && log "return 444; 已全部还原" || log "警告：还原后 nginx reload 失败，请手动 nginx -t 检查"
    ;;
  *)
    echo "用法: $0 off <IP> | $0 on"; exit 1 ;;
esac
