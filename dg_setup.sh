# Add shortcut aliases for setting the different Oracle environments (database, GSM)
cat << EOF >> ~/.bash_profile
alias $(echo $ORACLE_SID | tr [A-Z] [a-z])="export ORACLE_SID=$ORACLE_SID; export ORACLE_HOME=$ORACLE_HOME; export LD_LIBRARY_PATH=$ORACLE_HOME/lib; export PATH=$ORACLE_HOME/bin:$ORACLE_HOME/OPatch/:/usr/sbin:/usr/local/sbin:/usr/local/bin:/usr/sbin:/usr/bin:/sbin:/bin"
alias gsm="export ORACLE_HOME=$GSM_HOME; export LD_LIBRARY_PATH=$GSM_HOME/lib; export PATH=$GSM_HOME/bin:/usr/sbin:/usr/local/sbin:/usr/local/bin:/usr/sbin:/usr/bin:/sbin:/bin"
EOF

# Create directories
mkdir -p ${ORACLE_BASE}/oradata/${ORACLE_SID}/archivelog
mkdir -p ${ORACLE_BASE}/oradata/${ORACLE_SID}/autobackup
mkdir -p ${ORACLE_BASE}/oradata/${ORACLE_SID}/flashback
mkdir -p ${ORACLE_BASE}/fast_recovery_area

# Add static listener entries to listener.ora:
cat << EOF >> $ORACLE_HOME/network/admin/listener.ora

SID_LIST_LISTENER =
  (SID_LIST =
    (SID_DESC =
      (GLOBAL_DBNAME = ${ORACLE_SID})
      (ORACLE_HOME = ${ORACLE_HOME})
      (SID_NAME = ${ORACLE_SID})
    )
  )
EOF

# Restart the listener:
lsnrctl stop
lsnrctl start

# Remove the default localhost TNS entry:
sed -in '/localhost\:1521/d' $ORACLE_HOME/network/admin/tnsnames.ora

# Add the TNS entries for all databases in the cluster:
cat /opt/oracle/scripts/tnsnames.ora >> $ORACLE_HOME/network/admin/tnsnames.ora

# Perform database configuration
if [[ "$ROLE" = "PRIMARY" ]]
then

# Set up everything needed to be configured in the primary and catalog databases:
sqlplus "/ as sysdba" <<EOF
alter system set db_create_file_dest='/opt/oracle/oradata/${ORACLE_SID}' scope=both;
alter system set db_recovery_file_dest_size=5g scope=both;
alter system set db_recovery_file_dest='/opt/oracle/oradata/${ORACLE_SID}' scope=both;
alter system set dg_broker_start=true scope=both;
alter system set open_links=16 scope=spfile;
alter system set open_links_per_instance=16 scope=spfile;
alter system set event='10798 trace name context forever, level 7' SCOPE=spfile;
alter database force logging;
shutdown immediate
startup mount
alter database archivelog;
alter database flashback on;
alter database open;
alter user gsmuser account unlock;
alter user gsmcatuser account unlock;
alter user gsmcatuser identified by ${GSM_PASS};
alter session set container=${ORACLE_PDB};
alter system set events 'immediate trace name GWM_TRACE level 7';
create user ${GDS_USER} identified by ${GDS_PASS};
alter user ${GDS_USER} identified by ${GDS_PASS};
grant sysdg, sysbackup to gsmuser;
grant connect, create session, gsmadmin_role to ${GDS_USER};
grant read, write on directory data_pump_dir to gsmadmin_internal;
grant inherit privileges on user SYS to GSMADMIN_INTERNAL;
set serveroutput on
execute DBMS_GSM_FIX.validateShard
EOF

# Add standby redo logs to databases that are part of a DG config:
if [[ ! -z "$DG_TARGET" ]]
then
sqlplus "/ as sysdba" <<EOF
alter database add standby logfile ('/opt/oracle/oradata/${ORACLE_SID}/standby_redo01.log') size 200m;
alter database add standby logfile ('/opt/oracle/oradata/${ORACLE_SID}/standby_redo02.log') size 200m;
alter database add standby logfile ('/opt/oracle/oradata/${ORACLE_SID}/standby_redo03.log') size 200m;
ALTER SYSTEM SET STANDBY_FILE_MANAGEMENT=AUTO;
EOF
fi

else
# Create a pfile for startup of the DG replication target:
cat << EOF > $ORACLE_HOME/dbs/init${ORACLE_SID}.ora
*.db_name='${ORACLE_SID}'
EOF

# Shutdown the DG replication targets and start with the pfile:
sqlplus "/ as sysdba" <<EOF
shutdown abort
startup nomount pfile='${ORACLE_HOME}/dbs/init${ORACLE_SID}.ora';
EOF

fi
