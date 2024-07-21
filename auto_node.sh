#!/bin/bash
PATH=/bin:/sbin:/usr/bin:/usr/sbin:/usr/local/bin:/usr/local/sbin:~/bin
clean_bt(){
  sed -i "/bt.cn/d" /etc/hosts
}

no_btcheck(){
   path_1="/www/server/panel/data"
   path_2="/www/server/panel/install"
   echo -e "\e[1;31m=================================================================================\e[0m"
   for FILE in ${path_1}/userInfo.json ${path_1}/plugin_bin.pl ${path_1}/auth_list.json ${path_2}/public.sh /etc/init.d/bt; do
     lsattr ${FILE}
   done

get_bt=$(grep "bt.cn" /www/server/panel/pyenv/lib/python3.7/urllib/request.py)
   if [ "${get_bt}" ]; then
      echo "request.py result:"
        echo "==================================================================="
        grep "bt.cn" -C 3 /www/server/panel/pyenv/lib/python3.7/urllib/request.py
        echo "==================================================================="
   fi
   echo -e "\033[34m节点连接状态:\033[0m"
   curl -s -m 5 -w "域名:www.bt.cn       状态码:%{http_code}      解析IP:%{remote_ip}\n" https://www.bt.cn -o /dev/null
   curl -s -m 5 -w "域名:api.bt.cn       状态码:%{http_code}      解析IP:%{remote_ip}\n" https://api.bt.cn -o /dev/null
   curl -s -m 5 -w "域名:download.bt.cn  状态码:%{http_code}      解析IP:%{remote_ip}\n" http://download.bt.cn -o /dev/null
   curl -s -m 5 -w "域名:dg1.bt.cn       状态码:%{http_code}      解析IP:%{remote_ip}\n" http://dg1.bt.cn -o /dev/null
   curl -s -m 5 -w "域名:dg2.bt.cn       状态码:%{http_code}      解析IP:%{remote_ip}\n" http://dg2.bt.cn -o /dev/null
   curl -s -m 5 -w "外网测试             状态码:%{http_code}      解析IP:%{remote_ip}\n" https://www.baidu.com -o /dev/null
   echo -e "\033[34m\n系统DNS设置:\033[0m"
   sed -n  '/nameserver/p' /etc/resolv.conf
}


_fix_node(){
    host_ip=(42.157.129.47 36.133.1.8 125.90.93.52 116.10.184.219 123.129.198.130 103.179.243.14 128.1.164.196 45.76.53.20)
#   host_ip=(42.157.129.124)
    tmp_file1=/dev/shm/net_test1.pl
    [ -f "${tmp_file1}" ] && rm -f ${tmp_file1}
        touch $tmp_file1
    tmp_file2=/dev/shm/net_test2.pl
    [ -f "${tmp_file2}" ] && rm -f ${tmp_file2}
        touch $tmp_file2
    tmp_file3=/dev/shm/net_test3.pl
    [ -f "${tmp_file3}" ] && rm -f ${tmp_file3}
        touch $tmp_file3
    tmp_file4=/dev/shm/net_test4.pl
    [ -f "${tmp_file4}" ] && rm -f ${tmp_file4}
        touch $tmp_file4
    ser_name="api.bt.cn"
    for host in ${host_ip[@]};
        do
           NODE_CHECK=$(curl --resolv ${ser_name}:443:${host} --connect-timeout 3 -m 3 2>/dev/null -w "%{http_code} %{time_total}" https://${ser_name} -o /dev/null|xargs)
           NODE_STATUS=$(echo ${NODE_CHECK}|awk '{print $1}')
           TIME_TOTAL=$(echo ${NODE_CHECK}|awk '{print $2 * 1000 - 500}'|cut -d '.' -f 1)

           NODE_CHECK_1=$(curl --resolv ${ser_name}:80:${host} --connect-timeout 3 -m 3 2>/dev/null -w "%{http_code} %{time_total}" http://${ser_name} -o /dev/null|xargs)
           NODE_STATUS_1=$(echo ${NODE_CHECK_1}|awk '{print $1}')
           TIME_TOTAL_1=$(echo ${NODE_CHECK_1}|awk '{print $2 * 1000 - 500}'|cut -d '.' -f 1)
           if [ "${NODE_STATUS}" ==  "200" ] && [ "${NODE_STATUS_1}" == "200" ];then
                 echo "$host" >> $tmp_file3
                 if [ $TIME_TOTAL -lt 100 ] && [ $TIME_TOTAL_1 -lt 100 ];then
                                  echo "$host" >> $tmp_file1
                 fi
           fi
        done
    clean_bt
    host_ip1=$(cat $tmp_file1)
    for host1 in ${host_ip1[*]};
        do
          NODE_CHECK_2=$(curl --resolv ${ser_name}:443:${host1} --connect-timeout 3 -m 3 2>/dev/null -w "%{http_code} %{time_total} %{remote_ip}" https://${ser_name} -o /dev/null|xargs)
          echo "$(echo ${NODE_CHECK_2}|awk '{print $2 * 1000 - 500,$3}')" >> ${tmp_file2}
        done
    JIEDIAN=$(cat ${tmp_file2} |sort -r -g -t " " -k 1|tail -n 1|awk '{print $2}'|cut -d '' -f 1)

    host_ip2=$(cat $tmp_file3)
    for host2 in ${host_ip2[*]};
        do
          NODE_CHECK_3=$(curl --resolv ${ser_name}:443:${host2} --connect-timeout 3 -m 3 2>/dev/null -w "%{http_code} %{time_total} %{remote_ip}" https://${ser_name} -o /dev/null|xargs)
          echo "$(echo ${NODE_CHECK_3}|awk '{print $2 * 1000 - 500,$3}')" >> ${tmp_file4}
        done
    JIEDIAN1=$(cat ${tmp_file4} |sort -r -g -t " " -k 1|tail -n 1|awk '{print $2}'|cut -d '' -f 1)

    if [ "$JIEDIAN" == "" ]; then
        echo -e "\033[33m节点指定异常\033[0m"
        echo -e "\033[32m开始第二次自动修复中...\033[0m"
        if [ "$JIEDIAN1" == "" ]; then
            echo -e "\033[31m\n节点二次指定节点异常...\033[0m"
        else
            echo -e "\033[32m\n第二次修复节点成功... \033[0m"
            echo "$JIEDIAN1 www.bt.cn api.bt.cn download.bt.cn dg2.bt.cn dg1.bt.cn" >> /etc/hosts
        fi
    else
        echo "$JIEDIAN www.bt.cn api.bt.cn download.bt.cn dg2.bt.cn dg1.bt.cn" >> /etc/hosts
    fi
    rm -f ${tmp_file1} && rm -f ${tmp_file2} && rm -f ${tmp_file3} rm -f ${tmp_file4}
}

echo -e "\033[32m自动修复节点中... \033[0m"
_fix_node
echo -e "\033[32m开始测试节点...请勿中断程序... \033[0m"

bt_check_01=$(curl -s -m 5 -w "%{http_code}\n" https://www.bt.cn -o /dev/null)
bt_check_02=$(curl -s -m 5 -w "%{http_code}\n" https://api.bt.cn -o /dev/null)
bt_check_03=$(curl -s -m 5 -w "%{http_code}\n" http://download.bt.cn -o /dev/null)
bt_check_04=$(curl -s -m 5 -w "%{http_code}\n" http://dg1.bt.cn -o /dev/null)
bt_check_05=$(curl -s -m 5 -w "%{http_code}\n" http://dg2.bt.cn -o /dev/null)
#port=$(cat /www/server/panel/data/port.pl)
#ip=$(curl -sS --connect-timeout 10 -m 60 https://www.bt.cn/Api/getIpAddress)
pool= [ "$(cat /www/server/panel/data/ssl.pl 2>&1)" == "True" ] && pool=https || pool=http
check_ok(){
    echo -e "\033[32mhosts指定节点: $(sed -n  '/bt.cn/p' /etc/hosts|awk '{print $1}')\033[0m"
    echo -e "\033[32m域名解析节点:  $(curl -s -m 5 -w "%{remote_ip}\n" https://www.bt.cn -o /dev/null)\033[0m"
    echo -e "\e[1;34m节点连接测试正常，修复已完成！ 请登录面板查看是否正常\033[0m"
    if [  $pool == "https" ]; then
        echo -e "\n面板已启用SSL，请以https的形式访问面板"
    else
        echo -e "\n面板未开启SSL，请以http的形式访问面板"
    fi
}

if [ "${bt_check_01}" != 302 ] || [ "${bt_check_02}" != 200 ] || [ "${bt_check_03}" != 200 ] || [ "${bt_check_04}" != 200 ] || [ "${bt_check_05}" != 200 ]; then
    echo "================================================================================="
    clean_bt
    if [ "${bt_check_01}" != 302 ] || [ "${bt_check_02}" != 200 ] || [ "${bt_check_03}" != 200 ] || [ "${bt_check_04}" != 200 ] || [ "${bt_check_05}" != 200 ]; then
        no_btcheck
        echo -e "\e[1;31m\n 修复失败,请将上方红线至此段话显示的所有内容,截图完整上传宝塔论坛或发送给宝塔运维 \033[0m"
        echo -e "\033[31m——————————————————————————————————————————————————————————————————————————————————\033[0m"
    else
        check_ok
    fi    
else
        check_ok
fi
