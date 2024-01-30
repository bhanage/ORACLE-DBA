#!/bin/bash
###################################################################################
echo "prerequisites : - "
echo "1. Check OS - ORACLE LINUX "
echo "2. Check Hostname set or Not - "
	cat /etc/hostname
echo "3.Check ram is min 8GB : "
echo "and storage : min 80GB: "
echo "4.Check the swap is 16GB or 8 GB"
cat /proc/meminfo
df -h
echo "5.Check for the seperate partition /src for (.zip) file and /orahome for install"
lsblk
#
#
#
#
#
#
###################################################################################
echo "Do you want to start script : "
echo "y or n (default is y)"
read yn
if [ $yn == "n" ]; then
	exit
fi
echo "Installing Required Dependencies: "
yum install oracle-database-preinstall-19c.x86_64 -y
echo "================================"
echo "Checking the kerenl parameters: "
sysctl -p 
echo "================================"
echo "Check the user oracle and its required groups are created: "
tail /etc/passwd | grep "oracle"
tail /etc/group | grep "oracle"
echo "================================"
echo "Create Oracle home and Oracle Inventory"
mkdir -p /orahome/app/oracle/product/19.3.0/db_1
mkdir -p /orahome/app/oraInventory 
chown -R oracle:oinstall  /orahome /src

echo "ORACLE_HOME=/orahome/app/oracle/product/19.3.0/db_1" >> .bash_profile
echo "ORACLE_BASE=/orahome/app/oracle" >> .bash_profile
echo "PATH=$PATH:$ORACLE_HOME/bin:" >> .bash_profile
echo "DISPLAY=:0.0" >> .bash_profile
echo "export PATH ORACLE_HOME ORACLE_BASE DISPLAY" >> .bash_profile
source ~/.bash_profile
echo "For Oracle Login:"
su - oracle -c 'echo "ORACLE_HOME=/orahome/app/oracle/product/19.3.0/db_1" >> /home/oracle/.bash_profile'
su - oracle -c 'echo "ORACLE_BASE=/orahome/app/oracle" >> /home/oracle/.bash_profile'
su - oracle -c 'echo "PATH=$PATH:$ORACLE_HOME/bin:" >> /home/oracle/.bash_profile'
su - oracle -c 'echo "DISPLAY=:0.0" >> /home/oracle/.bash_profile'
su - oracle -c 'echo "export PATH ORACLE_HOME ORACLE_BASE DISPLAY" >> /home/oracle/.bash_profile'
su - oracle -c 'chown oracle:oinstall /home/oracle/.bash_profile'
su - oracle -c 'source /home/oracle/.bash_profile'
echo "==============================="
echo "Check env ORACLE set or not: "
env | grep "ORA"
echo "In oracle login: "
su - oracle -c 'env | grep "ORA"'
echo "Extracting oracle installation zip file to \$ORACLE_HOME"
su - oracle -c 'unzip /src/LINUX.X64_193000_db_home.zip -d /orahome/app/oracle/product/19.3.0/db_1'
echo "Enter installation type: "
echo "1.xterm 2.responsefile"
read option
case $option in
        1)      echo "Installing xterm"
		yum install xterm -y 
                echo "==================================="
                xhost +
                echo "xhost +" >> ~/.bash_profile
		echo "Now go to $ORACLE_HOME and run ./runInstaller in xterm"
		su - oracle -c 'xterm'
                ;;
        2)
		#set -x ##debuging
	        echo "Enter the response file name with absolute path: "
                read -r rfile
		echo "Entered file path: $rfile"
		if [  -f $rfile ];then
			echo "file path: $rfile *"
			cp "$rfile"  /orahome/app/oracle/product/19.3.0/db_1/db_172.rsp
                	chown oracle:oinstall /orahome/app/oracle/product/19.3.0/db_1/db_172.rsp
			ls -l /orahome/app/oracle/product/19.3.0/db_1/db_172.rsp
			su - oracle -c '/orahome/app/oracle/product/19.3.0/db_1/runInstaller -silent  -responseFile /orahome/app/oracle/product/19.3.0/db_1/db_172.rsp'
			echo "Do you want to create Database silently (using rsp file)"
			echo "y or n"
			read choice
			if [ $choice == "y" ];then
				echo "Enter the absolute path of the rsp file"
				read -r dbcaspfile
				if [ -f $dbcaspfile ];then
					cp $dbcaspfile /home/oracle/dbcaspfile.rsp
					echo "Check th file is exist or not in req location"
					ls -l  /orahome/app/oracle/product/19.3.0/db_1/dbcaspfile.rsp
					chown oracle:oinstall /home/oracle/dbcaspfile.rsp
					su - oracle -c 'dbca -createDatabase -silent -responseFile /home/oracle/dbcaspfile.rsp'
					echo "Enter the ORACLE_SID name for database"
					read sid
					su - oracle -c "export ORACLE_SID=$sid && sqlplus / as sysdba"
				else
			                echo "$dbcaspfile does not exists"
				fi
			fi
		else
			echo "$responsefile does not exists"
		fi
                ;;

	
	*)	echo "Invalid choice"
		;;
esac
