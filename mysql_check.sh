#!/bin/bash
unset MAILCHECK
. $HOME/.bash_profile
LogDir=/etc/keepalived/log
logfile=$LogDir/mysql_check.log
DBhost=localhost
DBuser=root
DBpasswd=Abcd321#
DBsocket=/mysql/product/data/mysql.sock
ConnCMD="-h$DBhost -u$DBuser -p$DBpasswd -S$DBsocket"
shopt -s expand_aliases
alias cdate='date +"%Y-%m-%d %H:%M:%S"'
InstSuffix=''
startMySQLcmd="systemctl start mysqld$InstSuffix"
stopKeepAliveDcmd="systemctl stop keepalived"
WaitTime=5
WaitCount=12
j=1
while true
do
mysqld_status=`mysqladmin $ConnCMD ping 2>/dev/null`
mysql_status=`mysql $ConnCMD -e"select 1;" 2>/dev/null|awk 'NR>1'`
if [ "$mysqld_status" == "mysqld is alive" ] && [ $mysql_status -eq 1 ];then
echo "$(cdate) [Note] MySQL Service is Normal." >> $logfile
exit 0
elif [ "$mysqld_status" == "mysqld is alive" ] && [ $mysql_status -ne 1 ];then
echo "$(cdate) [Warning] MySQL Service may be Hung." >> $logfile
exit 0
else
if [ $j -le $WaitCount ];then
echo "$(cdate) [Error] MySQL Service is Abnormal and will be restart." >> $logfile
$startMySQLcmd
else
echo "$(cdate) [Error] MySQL Service is still Abnormal After $WaitCount restarts." >> $logfile
$stopKeepAliveDcmd
echo "$(cdate) [Action] Keepalived is forced to perform a Failover." >> $logfile
break
fi
fi
sleep $WaitTime
let j++
done