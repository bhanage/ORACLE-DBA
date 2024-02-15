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
###Check DB is opened in read write mode
(
sqlplus -S / as sysdba<<EOF
select status from v\$instance;
EOF
)>/tmp/my_out.txt
cat /tmp/my_out.txt | grep "OPEN" >> /dev/null
if [ $? -ne 0 ];then
	echo "Database is not opened"
	exit
fi
###Check archivelog mode is enabled
(
sqlplus -S / as sysdba<<EOF
archive log list;
EOF
)>/tmp/my_out.txt
cat /tmp/my_out.txt | grep -o "Enabled" >> /dev/null
if [ $? -ne 0 ];then
	echo "Not in archive mode"
	exit
fi
echo "Database is running on `hostname`!"
##Find current sequence number 
(
sqlplus -S / as sysdba<<EOF
select SEQUENCE# from v\$log where status='CURRENT';
EOF
)>/home/oracle/carrot/my_out3.txt

