#!/bin/bash
#Script for health check monitoring
#OS related 
#1. Space related to file system
#2. space for ram,disk.
#3. high priority oracle related processes using top.

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
function os_file() {
	echo "space related to file system"
	orahome=`df -h | grep orahome | awk '{print $5}' | sed 's/%//'`
	u02=`df -h | grep u02 | awk '{print $5}' | sed 's/%//'`
	u03=`df -h | grep u03 | awk '{print $5}' | sed 's/%//'`
	src=`df -h | grep src | awk '{print $5}' | sed 's/%//'`
	if [[ $u02 -ge 65 ]];then
		echo "/u02 size is $u02"
	fi
	if [[ $u03 -ge 65 ]];then
                echo "/u03 size is $u03"
        fi
	if [[ $src -ge 65 ]];then
                echo "/src size is $src"
        fi
	if [[ $orahome -ge 65 ]];then
                echo "/orahome size is $orahome"
        fi
	echo " ---------- "	

}

function ram_size() {
	echo" ---------------- "
	echo "Size of the ram"
	free -h		
}
function disk_size() {
	echo " ------------- "
	sar
}
function oracle_processes() {
	echo " --------------- "
	top -o %CPU | grep oracle 
}
echo "OS LEVEL for health check monitoring for Oracle: "
echo "1. Space related to file system for oracle software "
echo "2. space for ram,disk."
echo "3. high priority oracle related processes using top."
while : 
do
echo "SELECT OPTION:[1-3] "
read option
case $option in

	1) 	os_file
		;;
	2) 	ram_size 
		disk_size
		;;
	3)	oracle_processes
		;;
	*)	echo "Invalid Option"
		exit
		;;
esac
done
