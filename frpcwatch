while true
do
    result=`ps aux|grep frpc.ini|grep -v grep|wc -l`
    if [ $result = '0' ]; then
        echo "未运行，开始运行"
        nohup /etc/frp/frpc -c /etc/frp/frpc.ini > /dev/null 2>&1  &
    else
        echo "运行中"
    fi
    sleep 15
done
