create database <database_name>
        user sys identified by <password>
        user system identified by <password>
        logfile Group 1 ('/u01/<database_name>/redo1a.log','/u02/<database_name>/redo1b.log')size 100M,
                Group 2 ('/u01/<database_name>/redo2a.log','/u02/<database_name>/redo2b.log')size 100M
        MAXLOGHISTORY 1
        MAXLOGFILES 16
        MAXLOGMEMBERS 3
        CHARACTER SET AL32UTF8
        EXTENT MANAGEMENT LOCAL
        DATAFILE '/u01/<database_name>/system01.dbf'
        SIZE 700M REUSE AUTOEXTEND ON NEXT 10240K MAXSIZE UNLIMITED
        SYSAUX DATAFILE '/u03/<database_name>/sysaux01.dbf'
        SIZE 700M REUSE AUTOEXTEND ON NEXT 10240K MAXSIZE UNLIMITED
        DEFAULT TABLESPACE users
        DATAFILE  '/u02/<database_name>/user.dbf'
        SIZE 500M REUSE AUTOEXTEND ON MAXSIZE UNLIMITED
        DEFAULT TEMPORARY TABLESPACE tempts1
        TEMPFILE '/u02/<database_name>/temp1.dbf' SIZE 50M REUSE AUTOEXTEND ON NEXT 640K MAXSIZE UNLIMITED
        UNDO TABLESPACE undotbs1
        DATAFILE '/u03/<database_name>/undo.dbf' SIZE 200M REUSE AUTOEXTEND ON NEXT 5120K MAXSIZE UNLIMITED;
