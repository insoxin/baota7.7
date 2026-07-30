plugin

wget -O linuxsys.zip https://github.com/insoxin/baota7.7/blob/main/plugin/linuxsys.zip?raw=true && unzip linuxsys.zip -d /www/server/panel/plugin/linuxsys && mv /www/server/panel/plugin/linuxsys/linuxsys/* /www/server/panel/plugin/linuxsys/ && rm -rf /www/server/panel/plugin/linuxsys/linuxsys/


wget -O task_manager.zip https://github.com/insoxin/baota7.7/blob/main/plugin/task_manager.zip?raw=true && unzip task_manager.zip -d /www/server/panel/plugin/task_manager/ && mv /www/server/panel/plugin/task_manager/task_manager/* /www/server/panel/plugin/task_manager/ && rm -rf /www/server/panel/plugin/task_manager/task_manager/


wget -O backup.zip https://github.com/insoxin/baota7.7/blob/main/plugin/backup.zip?raw=true && unzip backup.zip -d /www/server/panel/plugin/backup/ && mv /www/server/panel/plugin/backup/backup/* /www/server/panel/plugin/backup/ && rm -rf /www/server/panel/plugin/backup/backup/

宝塔配置全能备份
AI完善优化功能
<li>本地文件备份： 上传导入本地文件的方式需要在设置中开启开发者模式,成功后关闭开发者模式即可</li>
              <li>备份信息： FTP用户密码  网站配置相关信息 防火墙配置信息  计划任务  监控数据  面板日志信息</li>
              <li>备份/还原时可自行勾选需要的分类，未勾选的分类不会被备份或还原。</li>
              <li>还原备份： 还原FTP、网站、防火墙配置、计划任务、监控数据和面板日志信息，如面板中已存在，则跳过此项。</li>
              <li>计划任务： 还原时会同时恢复任务的执行脚本并写入系统crond，任务名称或标识重复则跳过。</li>
