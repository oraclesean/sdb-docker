   alter system set db_recovery_file_dest_size=5g scope=spfile;
   alter system set db_recovery_file_dest='$ORACLE_BASE/oradata/$ORACLE_SID/fast_recovery_area' scope=spfile;
   alter system set dg_broker_start=true scope=spfile;
   alter system set db_file_name_convert='$ORACLE_BASE/oradata/$ORACLE_SID/','$ORACLE_BASE/oradata/$DG_TARGET/' scope=spfile;
   alter system set standby_file_management=AUTO scope=spfile;

   alter database force logging;
   alter database archivelog;
   alter database flashback on;

   alter user gsmrootuser identified by oracle account unlock;
   grant sysdg, sysbackup to gsmrootuser;

   alter user gsmuser account unlock;
   alter user gsmuser identified by oracle;
   grant sysdg, sysbackup to gsmuser;

  create or replace directory DATA_PUMP_DIR as '$ORACLE_BASE/oradata';

   alter database add standby logfile thread 1 group 4 size 200m;
   alter database add standby logfile thread 1 group 5 size 200m;
   alter database add standby logfile thread 1 group 6 size 200m;
   alter database add standby logfile thread 1 group 7 size 200m;

   alter session set container=$ORACLE_PDB;

   grant read, write on directory data_pump_dir to gsmadmin_internal;
   alter user gsmuser account unlock;

/* Grant to GSMUSER in the PDB */
   grant sysdg, sysbackup to gsmuser;
