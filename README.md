# BTinstall_6.0
宝塔面板7.7原版安装脚本

宝塔面板7.8版本使用各种方法均无法绕过绑定账号，并且不绑定账号无法下载安装插件。

因此这里分享一下7.7版本的安装脚本，是官方免费版的。
```
wget -O install.sh https://raw.githubusercontent.com/insoxin/BTinstall_6.0/main/install_6.0.sh && bash install.sh
```

升级到7.7版本命令：
curl http://f.cccyun.cc/bt/update6.sh|bash


建议配合下面文章中的优化脚本使用：
这个是根据个人使用习惯做的宝塔面板一键优化补丁，主要有以下优化项目：
1.去除宝塔面板强制绑定账号
2.去除各种删除操作时的计算题与延时等待
3.去除创建网站自动创建的垃圾文件（index.html、404.html、.htaccess）
4.关闭未绑定域名提示页面，防止有人访问未绑定域名直接看出来是用的宝塔面板
5.关闭活动推荐与在线客服
```
wget -O optimize.sh https://raw.githubusercontent.com/insoxin/BTinstall_6.0/main/optimize.sh && bash optimize.sh

```
适用宝塔面板版本：7.7

全部使用补丁的方式，而不是替换文件的方式，方便后续升级版本的修改。


适用宝塔面板7.9版本的命令（7.9版本不支持去除强制绑定账号）：
wget -O optimize.sh http://f.cccyun.cc/bt/optimize_new.sh && bash optimize.sh
