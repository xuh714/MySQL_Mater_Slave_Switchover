#!/bin/bash
unset MAILCHECK
. $HOME/.bash_profile
ctime=$(date +"%Y-%m-%d_%H-%M-%S")
LogDir=/etc/keepalived/log
logfile=$LogDir/to_NewMaster_$ctime.log
dblog=$LogDir/to_NewMaster_$ctime.bin
Lhost=localhost
Luser=root
Lpasswd=Abcd321#
Lsocket=/mysql/product/data/mysql.sock
ConnCMD="-h$Lhost -u$Luser -p$Lpasswd -S$Lsocket"
Mhost=192.168.113.110
Chost=192.168.113.111
Ruser=repl
Rpasswd=Abcd321#
Rport=3307
MconnCMD="-h$Mhost -u$Ruser -p$Rpasswd -P$Rport"
VRRPvip=192.168.113.200
shopt -s expand_aliases
alias cdate='date +"%Y-%m-%d %H:%M:%S"'
alias vipmatchCMD=$(echo 'ip a|awk -v RS="@#$j" '"'"'{print gsub(/'"$VRRPvip"'/,"&")}'"'")
str1='mysql $ConnCMD -e"show global variables where Variable_name='
str2=';" 2>/dev/null|awk '"'"'{print $NF}'"'"'|awk '"'"'NR>1'"'"
str3='mysql $MconnCMD -e"show master status\G;" 2>/dev/null|grep -w '
str4='mysql $ConnCMD -e"show slave status\G;" 2>/dev/null|grep -w '
str5='|awk '"'"'{print $2}'"'"
alias BinPrefixCMD=$(echo $str1"'"log_bin_basename"'"$str2)
BinPrefixOpt=$(BinPrefixCMD)
BinPrefix=${BinPrefixOpt##*/}
alias gtid_modeCMD=$(echo $str1"'"gtid_mode"'"$str2)
gtid_modeOpt=$(gtid_modeCMD)
gtid_mode=${gtid_modeOpt##*/}
if [ "$gtid_mode" == "ON" ];then
CHANGEOPTS="MASTER_AUTO_POSITION = 1"
else
CHANGEOPTS="MASTER_LOG_FILE='$BinPrefix.000001', MASTER_LOG_POS=154"
fi
alias MasterLogFileCMD=$(echo $str3'"File:"'$str5)
alias MasterLogPosCMD=$(echo $str3'"Position:"'$str5)
alias ReadMasterLogFileCMD=$(echo $str4'"Master_Log_File"'$str5)
alias ReadMasterLogPosCMD=$(echo $str4'"Read_Master_Log_Pos"'$str5)
alias RelayMasterLogFileCMD=$(echo $str4'"Relay_Master_Log_File"'$str5)
alias ExecMasterLogPosCMD=$(echo $str4'"Exec_Master_Log_Pos"'$str5)
WaitTime=5
WaitCount=12
count=1
while [ $count -le $WaitCount ]
do
vipmatch=$(vipmatchCMD)
MasterLogFile=$(MasterLogFileCMD)
MasterLogPos=$(MasterLogPosCMD)
ReadMasterLogFile=$(ReadMasterLogFileCMD)
ReadMasterLogPos=$(ReadMasterLogPosCMD)
RelayMasterLogFile=$(RelayMasterLogFileCMD)
ExecMasterLogPos=$(ExecMasterLogPosCMD)
if [ $vipmatch -eq 1 ];then
echo "$(cdate) [Prerequisite 1] KeepAlived VRRP vip is already existed." >> $logfile
if [ -n "$MasterLogFile" ] && [ -n "$MasterLogPos" ];then
if [ "$MasterLogFile" == "$ReadMasterLogFile" ] && [ "$MasterLogPos" == "$ReadMasterLogPos" ];then
echo "$(cdate) [Prerequisite 2] Master and Slave io_thread's data has been synchronized." >> $logfile
if [ "$MasterLogFile" == "$RelayMasterLogFile" ] && [ "$MasterLogPos" == "$ExecMasterLogPos" ];then
echo "$(cdate) [Prerequisite 3] Master and Slave sql_thread's data has been synchronized." >> $logfile
echo "$(cdate) [Action] MySQL Replication Switchover is begining." >> $logfile
mysql $ConnCMD >/dev/null 2>&1 <<EOF
stop slave;
reset slave all;
reset master;
flush tables with read lock;
tee $dblog;
show master status\G;
notee;
set global read_only = off;
set global super_read_only = off;
unlock tables;
EOF
echo "$(cdate) [Action] MySQL Replication Switchover is end." >> $logfile
echo "$(cdate) [Action] MySQL Replication resync is begining." >> $logfile
mysql $MconnCMD >/dev/null 2>&1 <<EOF
change master to MASTER_HOST='$Chost', MASTER_USER='$Ruser', MASTER_PASSWORD='$Rpasswd', MASTER_PORT=$Rport, $CHANGEOPTS;
start slave;
EOF
echo "$(cdate) [Action] MySQL Replication resync is end." >> $logfile
exit 0
else
echo "$(cdate) [Warning] Master and Slave sql_thread's data has not yet been synchronized." >> $logfile
fi
else
echo "$(cdate) [Warning] Master and Slave io_thread's data has not yet been synchronized." >> $logfile
fi
else
echo "$(cdate) [Warning] Master is probably down." >> $logfile
fi
else
echo "$(cdate) [Warning] KeepAlived VRRP vip has not been obtained." >> $logfile
fi
sleep $WaitTime
let count++
done