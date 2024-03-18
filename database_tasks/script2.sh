#!/bin/bash
#Database related
# 1. Check the db is running at os level
# 2. Check the listener is up
# 3. Check the diskspace related to ASM.
# 4. Check the adrci related queries for ORA errors.
# 5. Check the adrci related queries for Warnings.
# 6. Check the All the oracle process related to the database that are created. (server process,background process)
# 7. Check the tablespace related statistics.
# 8. Check the database objects in tablespce related statistics.
# 9. Check the database is archivelog or not.
# 10.Check the size of db_archive_file_size is 90% full or not.
# 11.Check the backup mode is enable or not.

# Take all the sid, home dir in one file
cat /etc/oratab | grep :/ > /tmp/out1.txt
declare -a sid_array
k=0
declare -a not_archive
declare -a archive
declare -a run_sid
declare -a non_run_sid
for i in `cat /tmp/out1.txt | cut -d: -f1`
do
	sid_array[k]=$i
	((k++))
done

function db_up() {
	g=0
	for sid in "${sid_array[@]}"; do
		ps -ef | grep $sid | grep pmon >> /dev/null
		if [ $? -ne 0 ];then 
			non_run_sid[g]=$sid
		else
			run_sid[g]=$sid
		fi
		((g++))		
	done
	if [ ${#run_sid[@]} -ne 0 ];then
		echo "Running DataBases : ${run_sid[@]}"
	fi
	if [ ${#non_run_sid[@]} -ne 0 ];then
		echo "Not Running DataBases : ${non_run_sid[@]}"
	fi
}


function listener_status() {
	host=`hostname`
	for i in `ls /orahome/app/oraInventory/diag/tnslsnr/$host/`
	do
		lsnrctl status $i >> /dev/null
		if [ $? -ne 0 ];then
			echo "$i listener is not running."
		fi
	done
		/u02/app/grid/product/19.3.0/bin/srvctl status listener >> /dev/null
		if [ $? -ne 0 ];then
			/u02/app/grid/product/19.3.0/bin/srvctl status listener
		fi
}

function archivelog_mode() {
    p=0
    for sid in "${run_sid[@]}"; do
    export ORACLE_SID=$sid
    if [ "$sid" != "+ASM" ]; then
        (
            sqlplus -S / as sysdba <<EOF
            archive log list;
EOF
        ) > /tmp/out4.txt

        if grep -q "Enabled" /tmp/out4.txt; then
            archive[p]=$sid
        else
            not_archive[p]=$sid
        fi
	((p++))
    fi
    done
    echo "Database archive log enabled: ${archive[@]}"
    echo "Database archive log not enabled: ${not_archive[@]}"

}

function check_backupmode(){
	declare -a backup
	k=0
	for sid in "${archive[@]}"; do
		export ORACLE_SID=$sid	
		(	
		sqlplus -S / as sysdba<<EOF
		select * from v\$backup;
EOF
		)>/tmp/my_out.txt
		cat /tmp/my_out.txt | grep -o "NOT" >> /dev/null
		if [ $? -ne 0 ];then
			backup[k]=$sid
		fi
		((k++))
	done
	if [ ${#backup[@]} -ne 0 ];then
		echo "Database in backup mode: ${backup[@]}"
	else
		echo "Not any database is in backup mode"
	fi
}

function check_archivelog_dir_size() {
	
	echo "Size management of archivelog area is:"
	for sid in "${archive[@]}";do
		export ORACLE_SID=$sid
		sid_dir=`echo "$sid" | tr [:lower:] [:upper:]`
		(
		sqlplus -S / as sysdba<<EOF
		show parameter db_recovery_file_dest
EOF
		)>/tmp/my_out2.txt
		cat /tmp/my_out2.txt |  awk '{print $3}' | grep ORACLE_BASE >> /dev/null
		if [ $? -eq 0 ];then
			echo " For $sid database Standard recovery location:  "
			df -h $ORACLE_BASE/fast_recovery_area/$sid_dir
		else
			echo " For $sid database : "
			recovery_dir=`cat /tmp/my_out2.txt |  awk '{print $3}' | grep /`
			df -h $recovery_dir/$sid_dir
		fi	
	done		
}



function database_open_mode_role() {
	declare -a not_open
	declare -a open
	g=0
	echo ${run_sid[@]}
	for sid in "${run_sid[@]}";do
	if [ "$sid" != "+ASM" ];then
                export ORACLE_SID=$sid
		(	
		sqlplus -S / as sysdba<<EOF
		select status from v\$instance;
EOF
		)>/tmp/my_out.txt
		cat /tmp/my_out.txt | grep "OPEN" >> /dev/null
		if [ $? -eq 0 ];then
			open[g]=$sid
			echo "Database role for $sid is : "
			(
				sqlplus -S / as sysdba<<EOF
				select database_role from v\$database;
EOF
			)
		else
			not_open[g]=$sid
		fi
		((g++))
	fi
	done
	if [ ${#not_open} -ne 0 ];then
		echo "Database is not opened: ${not_open[@]}"
	fi
	if [ ${#open} -ne 0 ];then
		echo "Database is opened: ${open[@]}"
	fi
}
function asm_check() {

	source /home/oracle/gridenv
	declare -a asm_conn
	declare -a asm_not_conn
	b=0
	for sid in "${run_sid[@]}";do
		(
			sqlplus -S / as sysasm<<EOF
			select DB_NAME,GROUP_NUMBER,STATUS FROM V\$ASM_CLIENT where DB_NAME='$sid';
EOF
		)>/tmp/asm_out.txt
	cat /tmp/asm_out.txt | grep "no rows" >> /dev/null
	if [ $? -eq 0 ];then
		asm_not_conn[b]=$sid
	else
		asm_conn[b]=$sid
	fi
	((b++))
	done
	echo "Databases connected to asm are: ${asm_conn[@]}"
	echo "Databases not connected to asm are: ${asm_not_conn[@]}"

}
function asm_data() {
	source /home/oracle/gridenv
	declare -a asm_data
	declare -a not_asm_data
	p=0
	asmcmd ls +DATA >> /tmp/asm_data.txt
	for sid in ${sid_array[@]}
	do
		if [ "$sid" != '+ASM' ];then
			cat /tmp/asm_data.txt | grep -i $sid	>> /dev/null
			if [ $? -eq 0 ];then
				asm_data[p]=$sid
			else
				not_asm_data[p]=$sid
			fi
		fi
		((p++))		
	done
	if [ ${#asm_data[@]} -ne 0 ];then
		echo "Databases which are on ASM : ${asm_data[@]}"
	fi
	
	if [ ${#not_asm_data[@]} -ne 0 ];then
		echo "Databases which are on local disk : ${not_asm_data[@]}"
	fi
	
}
function asm_mem_info() {
	export ORACLE_BASE=/orahome/app/oraInventory
	export ORACLE_HOME=/orahome/app/oracle/product/19.3.0/db_1

	
	for sid in ${run_sid[@]}
        do
		if [ "$sid" != '+ASM' ];then
			export ORACLE_SID=$sid
			echo "For $sid Report For Memory is: "
			echo "SGA and PGA Information: "
			(
				sqlplus -S / as sysdba<<EOF
				select * from v\$sga;	
			        select sum(PGA_USED_MEM) "Used PGA Mem",sum(PGA_ALLOC_MEM) "Allocated PGA Mem",sum(PGA_FREEABLE_MEM) "Free PGA Mem",sum(PGA_MAX_MEM) "Max PGA Mem"  from v\$process;
EOF
			)>/tmp/asm_mem.data
			cat /tmp/asm_mem.data 
			echo "-----------------------"
		fi
	done
			
}


function blocking_sessions() {
	
	for sid in  ${run_sid[@]}
	do
		if [ "$sid" != '+ASM' ];then
			export ORACLE_SID=$sid
			(
				sqlplus -S / as sysdba<<EOF
				select name from v\$database;
				select s1.username || '@' || s1.machine || '( SID=' || s1.sid || ') is 
				blocking ' || s2.username || '@' || s2.machine || ' ( SID=' || s2.sid || ' ) ' 
				AS blocking_status from gv\$lock l1, gv\$session s1 , gv\$lock l2, gv\$session s2 
				where s1.sid=l1.sid AND s2.sid=l2.sid AND l1.BLOCK=1 AND l2.request > 0 
				AND l1.id1 = l2.id1 AND l1.id2 = l2.id2;
EOF
			)>/tmp/block_sess.data
			cat /tmp/block_sess.data | grep "no rows">>/dev/null
			if [ $? -ne 0 ];then
				echo "Blocking sessions: "
				cat /tmp/block_sess.data
				( 
						sqlplus -S / as sysdba<<EOF
						SELECT s.SID,s.SERIAL#,s.USERNAME,s.MACHINE,sq.SQL_TEXT FROM V\$SESSION s JOIN V\$SQL sq ON s.SQL_ID = sq.SQL_ID WHERE s.TYPE='USER'AND s.STATUS='ACTIVE';
EOF
				)>/tmp/block_sess.data
				echo "Active transactions on the $sid"
				cat /tmp/block_sess.data 
				echo "==============="
			fi
			
		
		fi
	done
	
}


function tablespace_statistics() {
	 for sid in  ${run_sid[@]}
     	 do
           if [ "$sid" != '+ASM' ];then
              export ORACLE_SID=$sid
	      echo "For Database: $sid Tablespace Statistics"
	      sqlplus -S / as sysdba <<EOF > /tmp/tablespace_report.txt
              set linesize 200;
              select * from dba_tablespace_usage_metrics;
EOF

	      cat /tmp/tablespace_report.txt
	      echo "==================="
	   fi
	done
}

function alert_log_errors() {
	for sid in ${run_sid[@]}
	do	
		if [ "$sid" == '+ASM' ];then
			echo "For $sid database Checking alert logs:" 
			tail -50 /u02/app/grid/diag/asm/+asm/+ASM/trace/alert_$sid.log	
			echo "========================="
		else
			export ORACLE_SID=$sid
			echo "For $sid database Checking alert Logs:" 
			tail -50 /orahome/app/oraInventory/diag/rdbms/$sid/$sid/trace/alert_$sid.log 
			echo "============================"
		fi		
	done
}
echo "Health monitoring report"
db_up
echo "****************"
listener_status
echo "****************"
archivelog_mode
echo "****************"
check_backupmode
echo "****************"
check_archivelog_dir_size
echo "****************"
database_open_mode_role
echo "****************"
asm_check
echo "****************"
asm_data
echo "****************"
asm_mem_info
echo "****************"
blocking_sessions
echo "****************"
tablespace_statistics
echo "****************"
alert_log_errors
echo "****************"
