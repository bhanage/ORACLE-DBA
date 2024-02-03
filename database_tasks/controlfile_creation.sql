--colors is name of the database
STARTUP NOMOUNT
CREATE CONTROLFILE REUSE DATABASE "colors" NORESETLOGS  ARCHIVELOG
    MAXLOGFILES 16
    MAXLOGMEMBERS 3
    MAXDATAFILES 30
    MAXINSTANCES 1
    MAXLOGHISTORY 292
LOGFILE
  GROUP 1 (
    '/u01/colors/redo1a.log',
    '/u02/colors/redo1b.log'
  ) SIZE 100M BLOCKSIZE 512,
  GROUP 2 (
    '/u01/colors/redo2a.log',
    '/u02/colors/redo2b.log'
  ) SIZE 100M BLOCKSIZE 512
-- STANDBY LOGFILE
DATAFILE
  '/u01/colors/system01.dbf',
  '/u03/colors/sysaux01.dbf',
  '/u03/colors/undo.dbf',
  '/u02/colors/user.dbf'
CHARACTER SET AL32UTF8
;
-- Configure RMAN configuration record 1
-- Replace * with correct password.
VARIABLE RECNO NUMBER;
EXECUTE :RECNO := SYS.DBMS_BACKUP_RESTORE.SETCONFIG('CHANNEL','DEVICE TYPE DISK FORMAT   ''/backup/%U'' MAXPIECESIZE 1 G');
-- Commands to re-create incarnation table
-- Below log names MUST be changed to existing filenames on
-- disk. Any one log file from each branch can be used to
-- re-create incarnation records.
-- ALTER DATABASE REGISTER LOGFILE '/orahome/app/oracle/fast_recovery_area/COLORS/archivelog/2024_02_03/o1_mf_1_1_%u_.arc';
-- ALTER DATABASE REGISTER LOGFILE '/orahome/app/oracle/fast_recovery_area/COLORS/archivelog/2024_02_03/o1_mf_1_1_%u_.arc';
-- Recovery is required if any of the datafiles are restored backups,
-- or if the last shutdown was not normal or immediate.
RECOVER DATABASE
-- All logs need archiving and a log switch is needed.
ALTER SYSTEM ARCHIVE LOG ALL;
-- Database can now be opened normally.
ALTER DATABASE OPEN;
-- Commands to add tempfiles to temporary tablespaces.
-- Online tempfiles have complete space information.
-- Other tempfiles may require adjustment.
ALTER TABLESPACE TEMPTS1 ADD TEMPFILE '/u02/colors/temp1.dbf' REUSE;
