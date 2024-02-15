#!/bin/bash
#Archivals are placed in the $ORACLE_BASE/fast_recovery_area
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
(
sqlplus -S / as sysdba<<EOF
shutdown immediate;
startup mount;
recover database using backup controlfile until cancel;
AUTO
alter database open read only;
shutdown immediate;
startup mount;
EOF
)
