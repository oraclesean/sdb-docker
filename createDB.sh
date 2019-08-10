#!/bin/bash
# LICENSE UPL 1.0
#
# Copyright (c) 1982-2018 Oracle and/or its affiliates. All rights reserved.
#
# Since: November, 2016
# Author: gerald.venzl@oracle.com
# Description: Creates an Oracle Database based on following parameters:
#              $ORACLE_SID: The Oracle SID and CDB name
#              $ORACLE_PDB: The PDB name
#              $ORACLE_PWD: The Oracle password
#
# DO NOT ALTER OR REMOVE COPYRIGHT NOTICES OR THIS HEADER.
#

set -e

# Check whether ORACLE_SID is passed on
export ORACLE_SID=${1:-ORCLCDB}

# Check whether ORACLE_PDB is passed on
export ORACLE_PDB=${2:-ORCLPDB1}

# Auto generate ORACLE PWD if not passed on
export ORACLE_PWD=${3:-"`openssl rand -base64 8`1"}
echo "ORACLE PASSWORD FOR SYS, SYSTEM AND PDBADMIN: $ORACLE_PWD";

# Replace place holders in response file
cp $ORACLE_BASE/$CONFIG_RSP $ORACLE_BASE/dbca.rsp
sed -i -e "s|###ORACLE_SID###|$ORACLE_SID|g" $ORACLE_BASE/dbca.rsp
sed -i -e "s|###ORACLE_PDB###|$ORACLE_PDB|g" $ORACLE_BASE/dbca.rsp
sed -i -e "s|###ORACLE_PWD###|$ORACLE_PWD|g" $ORACLE_BASE/dbca.rsp
sed -i -e "s|###ORACLE_BASE###|$ORACLE_BASE|g" $ORACLE_BASE/dbca.rsp
sed -i -e "s|###ORACLE_CHARACTERSET###|$ORACLE_CHARACTERSET|g" $ORACLE_BASE/dbca.rsp

# If there is greater than 8 CPUs default back to dbca memory calculations
# dbca will automatically pick 40% of available memory for Oracle DB
# The minimum of 2G is for small environments to guarantee that Oracle has enough memory to function
# However, bigger environment can and should use more of the available memory
# This is due to Github Issue #307
if [ `nproc` -gt 8 ]; then
   sed -i -e "s|totalMemory=2048||g" $ORACLE_BASE/dbca.rsp
fi;

# Create directories:
mkdir -p $ORACLE_BASE/oradata/$ORACLE_SID/archivelog
mkdir -p $ORACLE_BASE/oradata/$ORACLE_SID/autobackup
mkdir -p $ORACLE_BASE/oradata/$ORACLE_SID/flashback
mkdir -p $ORACLE_BASE/oradata/$ORACLE_SID/fast_recovery_area
mkdir -p $ORACLE_BASE/$ORACLE_SID/adump

# Add aliases to set up the environment:
cat << EOF >> $HOME/env
alias $(echo $ORACLE_SID | tr [A-Z] [a-z])="export ORACLE_SID=$ORACLE_SID; export ORACLE_HOME=$ORACLE_HOME; export LD_LIBRARY_PATH=$ORACLE_HOME/lib; export PATH=$ORACLE_HOME/bin:$ORACLE_HOME/OPatch/:/usr/sbin:/usr/local/sbin:/usr/local/bin:/usr/sbin:/usr/bin:/sbin:/bin"
alias gsm="export ORACLE_HOME=$GSM_HOME; export LD_LIBRARY_PATH=$GSM_HOME/lib; export PATH=$GSM_HOME/bin:/usr/sbin:/usr/local/sbin:/usr/local/bin:/usr/sbin:/usr/bin:/sbin:/bin"
EOF

chmod ug+x $HOME/env

# Create network related config files (sqlnet.ora, tnsnames.ora, listener.ora)
mkdir -p $ORACLE_HOME/network/admin
echo "NAME.DIRECTORY_PATH= (TNSNAMES, EZCONNECT, HOSTNAME)" > $ORACLE_HOME/network/admin/sqlnet.ora

# Listener.ora
cat << EOF > $ORACLE_HOME/network/admin/listener.ora
LISTENER =
(DESCRIPTION_LIST =
  (DESCRIPTION =
    (ADDRESS = (PROTOCOL = IPC)(KEY = EXTPROC1))
    (ADDRESS = (PROTOCOL = TCP)(HOST = 0.0.0.0)(PORT = 1521))
  )
)

DEDICATED_THROUGH_BROKER_LISTENER=ON
DIAG_ADR_ENABLED = off

SID_LIST_LISTENER =
  (SID_LIST =
    (SID_DESC =
      (GLOBAL_DBNAME = $ORACLE_SID)
      (ORACLE_HOME = $ORACLE_HOME)
      (SID_NAME = $ORACLE_SID)
    )
  )

SID_LIST_LISTENER =
  (SID_LIST =
    (SID_DESC =
      (GLOBAL_DBNAME = ${ORACLE_SID}_DGMGRL)
      (ORACLE_HOME = $ORACLE_HOME)
      (SID_NAME = $ORACLE_SID)
    )
  )
EOF

# TNSnames.ora
echo "$ORACLE_PDB=
(DESCRIPTION =
  (ADDRESS = (PROTOCOL = TCP)(HOST = 0.0.0.0)(PORT = 1521))
  (CONNECT_DATA =
    (SERVER = DEDICATED)
    (SERVICE_NAME = $ORACLE_PDB)
  )
)" > $ORACLE_HOME/network/admin/tnsnames.ora

# Copy the generated list of TNS entries to the local TNS file:
cat $ORACLE_BASE/scripts/tnsnames.ora >> $ORACLE_HOME/network/admin/tnsnames.ora

# Copy the TNS file to the GSM network directory:
cp $ORACLE_HOME/network/admin/tnsnames.ora $GSM_HOME/network/admin/tnsnames.ora

echo " "
echo "     Container name is: $CONTAINER_NAME"
echo "     Container role is: $ROLE"
echo "Container DG Target is: $DG_TARGET"
echo "             DB SID is: $ORACLE_SID"
echo " "

if [[ "$ROLE" = "PRIMARY" ]]; then

# #############################################################
#                  Prepare a primary database                 #
# #############################################################

# Start LISTENER and run DBCA
lsnrctl start

dbca -silent -createDatabase -responseFile $ORACLE_BASE/dbca.rsp \
  || cat /opt/oracle/cfgtoollogs/dbca/$ORACLE_SID/$ORACLE_SID.log \
  || cat /opt/oracle/cfgtoollogs/dbca/$ORACLE_SID.log

# Remove second control file, fix local_listener, make PDB auto open, enable EM global port
sqlplus / as sysdba << EOF
   ALTER SYSTEM SET control_files='$ORACLE_BASE/oradata/$ORACLE_SID/control01.ctl' scope=spfile;
   ALTER SYSTEM SET local_listener='';
   ALTER PLUGGABLE DATABASE $ORACLE_PDB SAVE STATE;
   EXEC DBMS_XDB_CONFIG.SETGLOBALPORTENABLED (TRUE);
   exit;
EOF

echo "###########################################"
echo " Running modifications to PRIMARY database"
echo "###########################################"
echo " "

sqlplus / as sysdba << EOF
alter database force logging;
alter system set db_create_file_dest='/opt/oracle/oradata/$ORACLE_SID' scope=both;
alter system set db_recovery_file_dest_size=5g scope=both;
alter system set db_recovery_file_dest='/opt/oracle/oradata/$ORACLE_SID' scope=both;
alter system set dg_broker_start=true scope=both;
alter system set open_links=16 scope=spfile;
alter system set open_links_per_instance=16 scope=spfile;
alter system set event='10798 trace name context forever, level 7' SCOPE=spfile;
shutdown immediate
startup mount
alter database archivelog;
alter database flashback on;
alter database open;
alter user gsmuser account unlock;
alter user gsmcatuser account unlock;
alter user gsmcatuser identified by $GSM_PASS;
alter session set container=$ORACLE_PDB;
alter system set events 'immediate trace name GWM_TRACE level 7';
create user $GDS_USER identified by $GDS_PASS;
alter user $GDS_USER identified by $GDS_PASS;
grant sysdg, sysbackup to gsmuser;
grant connect, create session, gsmadmin_role to $GDS_USER;
grant read, write on directory data_pump_dir to gsmadmin_internal;
grant inherit privileges on user SYS to GSMADMIN_INTERNAL;
set serveroutput on
spool $ORACLE_BASE/validateShard.out
execute DBMS_GSM_FIX.validateShard
spool off
EOF

if [ -f $ORACLE_BASE/validateShard.out ]; then
echo "#############################################"
echo "### Results of DBMS_GSM_FIX.validateShard ###"
echo "#############################################"
cat $ORACLE_BASE/validateShard.out
echo " "

shardStatus=$(egrep -i "ERROR|WARNING" $ORACLE_BASE/validateShard.out | wc -l)

    if [ $shardStatus -gt 0 ]; then
       echo "#############################################"
       echo " validateShard produced one or more errors or"
       echo " warnings. Check the output of the procedure."
       echo "#############################################"
       echo " "
    fi
fi

# Remove auditing
# noaudit all;
# noaudit all on default;

# If this database has a DG Target assigned, create the standby redo logs:
if [[ ! -z "$DG_TARGET" ]]; then

echo "#############################################"
echo " Preparing $ORACLE_SID standby configuration"
echo "#############################################"
echo " "

# Add standby logs
sqlplus "/ as sysdba" <<EOF
alter database add standby logfile ('/opt/oracle/oradata/$ORACLE_SID/standby_redo01.log') size 200m;
alter database add standby logfile ('/opt/oracle/oradata/$ORACLE_SID/standby_redo02.log') size 200m;
alter database add standby logfile ('/opt/oracle/oradata/$ORACLE_SID/standby_redo03.log') size 200m;
alter system set standby_file_management=AUTO;
EOF

# Duplicate database for DG
echo "#############################################"
echo " Beginning duplicate of $ORACLE_SID to $DG_TARGET"
echo "#############################################"
echo " "

mkdir -p $ORACLE_BASE/cfgtools/rmanduplicate
rman target sys/$ORACLE_PWD@$ORACLE_SID auxiliary sys/$ORACLE_PWD@$DG_TARGET log=$ORACLE_BASE/cfgtoollogs/rmanduplicate/$ORACLE_SID.log << EOF
duplicate target database
      for standby
     from active database
          dorecover
          spfile set db_unique_name='$DG_TARGET'
          nofilenamecheck;
EOF

cat $ORACLE_BASE/cfgtools/rmanduplicate/$ORACLE_SID.log

echo "#############################################"
echo " Starting and configuring DataGuard Broker"
echo "#############################################"
echo " "

sqlplus "/ as sysdba" <<EOF
alter system set dg_broker_start=true;
EOF

dgmgrl sys/$ORACLE_PWD@$ORACLE_SID << EOF
create configuration $DG_CONFIG as primary database is $ORACLE_SID connect identifier is $ORACLE_SID;
add database $DG_TARGET as connect identifier is $DG_TARGET maintained as physical;
enable configuration;
show configuration;
show database $ORACLE_SID
show database $DG_TARGET
EOF

fi

else

# #############################################################
#                  Prepare a standby database                 #
# #############################################################

# Prepare the standby database.
echo "###########################################"
echo " Running modifications to STANDBY database"
echo "###########################################"
echo " "

# Create a pfile for startup of the DG replication target:
cat << EOF > $ORACLE_HOME/dbs/initDG.ora
*.db_name='$ORACLE_SID'
EOF

# Create a password file on the replication target.
# NOTE: Couldn't get this to work as a straight command, had to create a dummy script and call it separately to avoid OPW-00001
cat << EOF > $ORACLE_BASE/createPWF.sh
rm $ORACLE_HOME/dbs/orapw${ORACLE_SID}
$ORACLE_HOME/bin/orapwd file=${ORACLE_BASE}/oradata/dbconfig/${ORACLE_SID}/orapw${ORACLE_SID} force=yes format=12 <<< $ORACLE_PWD
ln -s $ORACLE_BASE/oradata/dbconfig/$ORACLE_SID/orapw$ORACLE_SID $ORACLE_HOME/dbs
EOF
chmod 700 $ORACLE_BASE/createPWF.sh
$ORACLE_BASE/createPWF.sh
rm $ORACLE_BASE/createPWF.sh

# Start the DG target database in nomount
sqlplus / as sysdba <<EOF
startup nomount pfile='$ORACLE_HOME/dbs/initDG.ora';
EOF

# Start listener
lsnrctl start

echo "#########################################"
echo " End of modifications to STANDBY database"
echo "#########################################"
echo " "
fi

# Remove temporary response file
rm $ORACLE_BASE/dbca.rsp
