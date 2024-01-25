#!/bin/bash
if [ -z $1 ];then
	echo "ORACLE_SID is not set"
	exit
fi
ORACLE_HOME=/orahome/app/oracle/product/19.3.0/db_1
ORACLE_BASE=/orahome/app/oracle
PATH=/usr/local/bin:/bin:/usr/bin:/usr/local/sbin:/usr/sbin:/home/oracle/.local/bin:/home/oracle/bin:/orahome/app/oracle/product/19.3.0/db_1/bin:
ORACLE_SID=$1
export ORACLE_HOME ORACLE_BASE PATH ORACLE_SID
ps -ef | grep ora_pmon_$ORACLE_SID | grep -v grep
if [ $? -ne 0 ];then
	echo "Database is not running os level"
	exit
fi
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
(
sqlplus -S / as sysdba<<EOF
select * from v\$backup;
EOF
)>/tmp/my_out.txt
cat /tmp/my_out.txt | grep -o "NOT" >> /dev/null
if [ $? -ne 0 ];then
	echo "Backup mode is enabled"
	exit
fi
(
sqlplus -S / as sysdba<<EOF
alter system switch logfile;
/
select sequence# from v\$log where status='CURRENT';
EOF
)>/tmp/my_out.txt
seqnumber=`cat /tmp/my_out.txt | tail -n 2`
echo "Current sequence number is $seqnumber"
(
sqlplus -S / as sysdba<<EOF
alter database begin backup;
select name from v\$datafile;
select name from v\$tempfile;
EOF
)>/tmp/my_two.txt

for i in `cat /tmp/my_two.txt | grep "/"`
do
	cp -v $i /home/oracle/hotbackup
done
echo "Ending Backup"
(
sqlplus -S / as sysdba<<EOF
alter database end backup;
alter system switch logfile;
/
alter database backup controlfile to '/tmp/controlfile1.dbf';
select status from v\$backup;
EOF
)>/tmp/my_out.txt
echo "Backup is completed"
cp -v /tmp/controlfile1.dbf /home/oracle/hotbackup
cat /tmp/my_out.txt | grep -o "NOT" >> /dev/null
if [ $? -ne 0 ];then
        echo "Backup mode is enabled"
        exit
fi
(
sqlplus -S / as sysdba<<EOF
select sequence# from v\$log where status='ACTIVE';
EOF
)>/tmp/my_out.txt
lastseq=`cat /tmp/my_out.txt`
echo "Last sequence number is $lastseq"
day=`date | cut -f3 -d ' '`
cp /orahome/app/oracle/fast_recovery_area/COLORS/archivelog/2024_01_$day/o1_mf_1_$seqnumber* /home/oracle/hotbackup
cp /orahome/app/oracle/fast_recovery_area/COLORS/archivelog/2024_01_$day/o1_mf_1_$lastseq* /home/oracle/hotbackup
cp /orahome/app/oracle/product/19.3.0/db_1/dbs/initcolors.ora /home/oracle/hotbackup 
#scp /home/oracle/hotbackup/* oracle@192.168.25.140:/src/colors/hotbackup 
