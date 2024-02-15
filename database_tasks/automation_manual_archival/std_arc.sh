#!/bin/bash
if [ -z $1 ];then
	echo "Set ORACLE_SID"
	exit;
fi
PATH=$PATH:$HOME/.local/bin:$HOME/bin
ORACLE_HOME=/orahome/app/oracle/product/19.3.0/db_1
ORACLE_BASE=/orahome/app/oraInventory
PATH=$ORACLE_HOME/bin:$PATH
export ORACLE_SID=$1
export PATH ORACLE_HOME  ORACLE_BASE

###Check DB is running
ps -ef | grep ora_pmon_$ORACLE_SID | grep -v grep
if [ $? -ne 0 ];then
	echo "Database is not running os level"
	exit
fi

###Check DB is mounted mode
(
sqlplus -S / as sysdba<<EOF
select status from v\$instance;
EOF
)>/home/oracle/carrot/my_out1.txt
cat /home/oracle/carrot/my_out1.txt | grep "MOUNTED" >> /dev/null
if [ $? -ne 0 ];then
	echo "Database is not in MOUNTED state"
	exit
fi
###Check archivelog mode is enabled
(
sqlplus -S / as sysdba<<EOF
archive log list;
EOF
)>/home/oracle/carrot/my_out2.txt
cat /home/oracle/carrot/my_out2.txt | grep -o "Enabled" >> /dev/null
if [ $? -ne 0 ];then
	echo "Not in archive mode"
	exit
fi
###Generate required sequence number
(
sqlplus -S / as sysdba<<EOF
select max(SEQUENCE#) from v\$log_history;
EOF
)>/home/oracle/carrot/my_out3.txt
last_arch_given=`cat my_out3.txt | tail -n 2 | awk '{print $1}'`
###Remotely copying all the archivals
req_arc=`expr $last_arch_given + 1`
day=`date +%d`
month=`date +%m`
year=`date +%Y`
sid_dir=`echo "$ORACLE_SID" | tr [:lower:] [:upper:]`
date_dir=${year}_${month}_${day} 
ssh oracle@192.168.25.167 sh /home/oracle/archivelog.sh $1
ssh oracle@192.168.25.167 sh /home/oracle/carrot/latestseq.sh
count=ssh oracle@192.168.25.167 cat my_out3.txt  | tail -n 2 | awk '{print $1}'
echo $count
while [ $count -ge $re_arc ];do
	filename=`ssh oracle@192.168.25.167 find $ORACLE_BASE/fast_recovery_area/$sid_dir/archivelog/$date_dir/ -name "o1_mf_1_${req_arc}*"`
	if [ $? -eq 0 ];then
       		 scp  oracle@192.168.25.167:$ORACLE_BASE/fast_recovery_area/$sid_dir/archivelog/$date_dir/o1_mf_1_${req_arc}* oracle@192.168.25.161:$ORACLE_BASE/fast_recovery_area/$sid_dir/archivelog/$date_dir/
	fi
	
	req_arc=`expr $req_arc + 1`
	
done
echo "Running script of archival logs applying after 5 minutes of interval" 
sleep 5m; 
sh applyarc.sh $1
