# sing-box setup_proxy.sh

解析节点链接并拉起本地代理：SOCKS5 `127.0.0.1:1080`、HTTP `127.0.0.1:1081`。
支持 vless / vmess / trojan / hysteria2(hy2) / tuic / anytls / socks5。

## 一句话安装（指定 1.13.16）

```bash
curl -fsSL https://raw.githubusercontent.com/insoxin/baota7.7/refs/heads/main/sing-box/sing-box-setup_proxy.sh | SING_BOX_VERSION=1.13.16 NODE_LINK='vless://uuid@example.com:443?security=reality&pbk=xxx&sni=example.com' GITHUB_ENV=/dev/null bash
```

自动装最新稳定版就去掉 `SING_BOX_VERSION`。

## 环境变量

| 变量 | 说明 |
| --- | --- |
| `NODE_LINK` | 节点链接，单引号包住。留空则直连模式，不装 sing-box |
| `SING_BOX_VERSION` | 版本号，`1.13.16` / `v1.13.16` / `latest`。留空取最新稳定版 |
| `GITHUB_ENV` | Actions 自动注入；裸跑必须给值，否则 `ambiguous redirect` 退出 1 |

指定了版本就不回退，下载失败直接报错（钉版本还静默换掉没意义）；没指定才在失败时退到备用版 `1.13.16`。

## GitHub Actions

```yaml
- env:
    NODE_LINK: ${{ secrets.NODE_LINK }}
    SING_BOX_VERSION: '1.13.16'   # 留空即最新版
  run: ./sing-box-setup_proxy.sh

- if: env.IS_PROXY == 'true'
  run: curl -x $PROXY_SERVER https://api.ipify.org
```

成功后写入 `IS_PROXY=true`、`PROXY_SERVER=socks5://127.0.0.1:1080`。

## 注意

- 脚本会 `pkill -f sing-box` 杀掉本机所有 sing-box 进程，本地跑留意。
- 依赖 `curl`/`wget`、`tar`、`jq`（缺失时尝试 `sudo apt-get install`）。
- 架构自动识别 amd64 / 386 / arm64 / armv7 / s390x；钉老版本注意其未必提供当前架构资产。
