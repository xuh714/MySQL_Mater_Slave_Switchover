#!/bin/bash
# 2020-05-22 MySQL master set read only mode and switchover to new slave Script version 1.0 (Author : xuh)
unset MAILCHECK
. $HOME/.bash_profile
ctime=$(date +"%Y-%m-%d_%H-%M-%S")
LogDir=/etc/keepalived/log
logfile=$LogDir/to_setROmode_$ctime.log
dblog=$LogDir/to_setROmode_$ctime.bin
DBhost=localhost
DBuser=root
DBpasswd=Abcd321#
DBsocket=/mysql/product/data/mysql.sock
ConnCMD="-h$DBhost -u$DBuser -p$DBpasswd -S$DBsocket"
shopt -s expand_aliases
alias cdate='date +"%Y-%m-%d %H:%M:%S"'
echo "$(cdate) [Action] To set Master Read Only mode after KeepAlived Failover is begining." >> $logfile
mysql $ConnCMD >/dev/null 2>&1 <<EOF
flush table with read lock;
tee $dblog;
show master status\G;
notee;
set global read_only=on;
set global super_read_only=on;
unlock tables;
EOF
echo "..." >> $logfile
echo "$(cdate) [Action] To set Master Read Only mode after KeepAlived Failover is end." >> $logfile
