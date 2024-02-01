#!/bin/bash
###########################################################
#This is Hot Backup Script
#$1 is oracle_sid 
#$2 is destination remote ip 
#$3 is destination remote username
#hotbackup directory path : /home/oracle/hotbackup
###########################################################
validation() {
#1.function is for validation
if [ -z $1  ] || [ -z $2 ] || [ -z $3 ];then
	echo "check all 3 input"
	echo "1.oracle sid"
	echo "2.destination remote ip"
	echo "3.destination remote username"
	exit
fi
if [ ! -d "/home/oracle/hotbackup" ]; then
	mkdir -p /home/oracle/hotbackup
else
	dir_content=`ls /home/oracle/hotbackup | wc -l`
	if [ $dir_content -ne 0 ];then
		echo "hotbackup directory is not empty!"
		exit
	fi
fi
ORACLE_HOME=/orahome/app/oracle/product/19.3.0/db_1
ORACLE_BASE=/orahome/app/oracle
PATH=/usr/local/bin:/bin:/usr/bin:/usr/local/sbin:/usr/sbin:/home/oracle/.local/bin:/home/oracle/bin:/orahome/app/oracle/product/19.3.0/db_1/bin:
ORACLE_SID=$1
export ORACLE_HOME ORACLE_BASE PATH ORACLE_SID
}
database_os_status() {
#2.function is to check wheather database is up or not at os level
ps -ef | grep ora_pmon_$ORACLE_SID | grep -v grep
if [ $? -ne 0 ];then
	echo "Database is not running os level"
	exit
fi
}
database_rw() {
#3.function is to check wheather database is opened in RW mode or not 
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
}
check_archivemode(){
#4.function is to check archivemode enabled or not
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
}
check_backupmode(){
#5.function to check backup mode is must be off 
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
}
check_seqnumber() {
#6.function note the current seqnumber
(
sqlplus -S / as sysdba<<EOF
alter system switch logfile;
/
select sequence# from v\$log where status='CURRENT';
EOF
)>/tmp/my_out2.txt
seqnumber=`cat /tmp/my_out2.txt | tail -n 2 | awk '{print $1}'`
echo "Current sequence number is $seqnumber"
}
start_backup() {
#7.function is to begin backup
(
sqlplus -S / as sysdba<<EOF
alter database begin backup;
select name from v\$datafile;
select name from v\$tempfile;
EOF
)>/tmp/my_two.txt
#(
#sqlplus -S / as sysdba<<EOF
#insert into car values(3,'Honda Civic');
#insert into car values(4,'Chevrolet Silverado');
#insert into car values(5,'BMW 3 Series');
#select * from car;
#alter system switch logfile;
#/
#EOF
#)>/tmp/my_three.txt
#cat /tmp/my_three.txt
}
end_backup() {
#8.function is to copy datafiles and tempfile & end backup

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
select status from v\$backup;
set lin 1200
select * from v\$log;
EOF
)>/tmp/my_out1.txt
echo "Backup is completed"
}
cp_control_initora_files () {
#9.check backup is ended completely & copy controlfile,initoracle_sid.ora
cat /tmp/my_out1.txt | grep -o "NOT" >> /dev/null
if [ $? -ne 0 ];then
        echo "Backup mode is enabled"
        exit
fi
if [ -f /tmp/cntrl.dbf ];then
	mv /tmp/cntrl.dbf /tmp/cntrl1.dbf
fi
(
sqlplus -S / as sysdba<<EOF
alter database backup controlfile to '/tmp/cntrl.dbf';
EOF
)>/tmp/my_out.txt
lastseq=`cat /tmp/my_out1.txt  | tail -n 3 | grep "ACTIVE" | awk '{print $3}'`
echo "Last sequence number is $lastseq"
cp -v /tmp/cntrl.dbf /home/oracle/hotbackup
}
remotecopy_files() {
#10.create hotbackup directory in definite location
remote="$3@$2"
echo "$remote"
ssh $remote mkdir -p /scr/hotbackup/colors
day=`date +%d`
month=`date +%m`
year=`date +%Y`
sid_dir=`echo "$ORACLE_SID" | tr [:lower:] [:upper:]`
date_dir=${year}_${month}_${day}
while [ $lastseq -ge $seqnumber ];do
	echo "In while $seqnumber"
	filename=`find $ORACLE_BASE/fast_recovery_area/$sid_dir/archivelog/$date_dir/ -name "o1_mf_1_${seqnumber}*"`
	cp -v $filename /home/oracle/hotbackup
	seqnumber=`expr $seqnumber + 1`
done
scp /home/oracle/hotbackup/* $remote:/scr/hotbackup/colors/ 
}


##################################
#calling functions
#1.
validation $1 $2 $3 
#2.
database_os_status
#3.
database_rw
#4.
check_archivemode
#5.
check_backupmode
#6.
check_seqnumber
#7.
start_backup
#8.
end_backup
#9.
cp_control_initora_files
#10.
remotecopy_files $1 $2 $3
