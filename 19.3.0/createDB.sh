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
mkdir -p $ORACLE_BASE/oradata/dbconfig/$ORACLE_SID
mkdir -p $ORACLE_BASE/oradata/$ORACLE_SID/archivelog
mkdir -p $ORACLE_BASE/oradata/$ORACLE_SID/autobackup
mkdir -p $ORACLE_BASE/oradata/$ORACLE_SID/flashback
mkdir -p $ORACLE_BASE/oradata/$ORACLE_SID/fast_recovery_area
mkdir -p $ORACLE_BASE/admin/$ORACLE_SID/adump

# Add aliases to set up the environment:
cat << EOF >> $HOME/.bashrc

alias $(echo $ORACLE_SID | tr [A-Z] [a-z])="export ORACLE_SID=$ORACLE_SID; export ORACLE_HOME=$ORACLE_HOME; export LD_LIBRARY_PATH=$ORACLE_HOME/lib; export PATH=$ORACLE_HOME/bin:$ORACLE_HOME/OPatch/:/usr/sbin:/usr/local/sbin:/usr/local/bin:/usr/sbin:/usr/bin:/sbin:/bin"
alias gsm="export ORACLE_HOME=$GSM_HOME; export LD_LIBRARY_PATH=$GSM_HOME/lib; export PATH=$GSM_HOME/bin:/usr/sbin:/usr/local/sbin:/usr/local/bin:/usr/sbin:/usr/bin:/sbin:/bin"
EOF

# Create network related config files (sqlnet.ora, tnsnames.ora, listener.ora)
mkdir -p $ORACLE_HOME/network/admin
echo "NAME.DIRECTORY_PATH= (TNSNAMES, EZCONNECT, HOSTNAME)" > $ORACLE_HOME/network/admin/sqlnet.ora

# Create the listener.ora and include a static listener entry for Data Guard:
  if [ "$SHARD_ROLE" = "CATALOG" ]
then # End the SID_LIST_LISTENER entry:
     LISTENER_EOF="  )"
else # Add an entry for the DG SID:
     LISTENER_EOF="    (SID_DESC =
      (GLOBAL_DBNAME = $DG_TARGET)
      (ORACLE_HOME = $ORACLE_HOME)
      (SID_NAME = $ORACLE_SID)
    )
  )"
fi

cat << EOF > $ORACLE_HOME/network/admin/listener.ora
LISTENER =
  (DESCRIPTION_LIST =
    (DESCRIPTION =
      (ADDRESS = (PROTOCOL = TCP)(HOST = $HOSTNAME)(PORT = 1521))
    )
  )

SID_LIST_LISTENER =
  (SID_LIST =
    (SID_DESC =
      (GLOBAL_DBNAME = $DB_UNQNAME)
      (ORACLE_HOME = $ORACLE_HOME)
      (SID_NAME = $ORACLE_SID)
    )
$LISTENER_EOF
EOF

# The TNS file is generated by compose.
# Copy the generated TNS entries to the local TNS and GSM network directories:
cp $ORACLE_BASE/scripts/tnsnames.ora $ORACLE_HOME/network/admin/tnsnames.ora
cp $ORACLE_BASE/scripts/tnsnames.ora $GSM_HOME/network/admin/tnsnames.ora

# Copy the GSM file to the GSM network directory:
cat $ORACLE_BASE/scripts/gsm.ora >> $GSM_HOME/network/admin/gsm.ora

echo " "
echo "      Container name is: $CONTAINER_NAME"
echo "      Container role is: $ROLE"
echo "              DB SID is: $ORACLE_SID"
echo "Database Unique Name is: $DB_UNQNAME"
echo " "

# #############################################################
#                        Prepare databases                    #
# #############################################################

# Start LISTENER and run DBCA
lsnrctl start

dbca -silent -createDatabase -responseFile $ORACLE_BASE/dbca.rsp \
  || cat /opt/oracle/cfgtoollogs/dbca/$ORACLE_SID/$ORACLE_SID.log \
  || cat /opt/oracle/cfgtoollogs/dbca/$ORACLE_SID.log

# Remove second control file, fix local_listener, make PDB auto open, enable EM global port
$ORACLE_HOME/bin/sqlplus / as sysdba << EOF
ALTER SYSTEM SET control_files='$ORACLE_BASE/oradata/$ORACLE_SID/control01.ctl' scope=spfile;
ALTER SYSTEM SET local_listener='';
ALTER PLUGGABLE DATABASE $ORACLE_PDB SAVE STATE;
EXEC DBMS_XDB_CONFIG.SETGLOBALPORTENABLED (TRUE);
alter system set db_create_file_dest='$ORACLE_BASE/oradata' scope=both;
alter system set open_links=16 scope=spfile;
alter system set open_links_per_instance=16 scope=spfile;
noaudit all;
noaudit all on default;
EOF

  if [ "$SHARD_ROLE" = "CATALOG" ]
then echo "###########################################"
     echo " Running modifications to CATALOG database"
     echo "###########################################"
     echo " "

     $ORACLE_HOME/bin/sqlplus / as sysdba << EOF
shutdown immediate
startup
alter user gsmcatuser account unlock;
alter user gsmcatuser identified by $GSM_PASS;
alter session set container=$ORACLE_PDB;
alter user gsmcatuser account unlock;
create user $SDB_ADMIN identified by $SDB_PASS;
alter user $SDB_ADMIN identified by $SDB_PASS;
grant connect, create session, gsmadmin_role to $SDB_ADMIN;
-- Set up the scheduler agent
exec dbms_xdb.sethttpport(8080);
@?/rdbms/admin/prvtrsch.plb
exec dbms_scheduler.set_agent_registration_pass('$SDB_PASS');
EOF

     # End of CATALOG changes.

else echo "###########################################"
     echo " Running modifications to SHARD databases"
     echo "###########################################"
     echo " "

     # Check to see if the GSMROOTUSER exists:
     gsmrootuser=$(sed -e '/^$/d' -e 's/^[ \t]*//' <($ORACLE_HOME/bin/sqlplus -S / as sysdba << EOF
set head off feedback off
select 'create user gsmrootuser;' from dual where (select count(username) from dba_users where username = 'GSMROOTUSER') = 0;
EOF
))

     $ORACLE_HOME/bin/sqlplus / as sysdba << EOF
set echo on
alter system set db_recovery_file_dest_size=5g scope=spfile;
alter system set db_recovery_file_dest='$ORACLE_BASE/oradata/$ORACLE_SID/fast_recovery_area' scope=spfile;
alter system set dg_broker_start=true scope=spfile;
alter system set db_file_name_convert='$ORACLE_BASE/oradata/$ORACLE_SID/','$ORACLE_BASE/oradata/$DG_TARGET/' scope=spfile;
alter system set standby_file_management=AUTO scope=spfile;
shutdown immediate
startup mount
alter database force logging;
alter database archivelog;
alter database flashback on;
alter database open;
$gsmrootuser
alter user gsmrootuser identified by $GSM_PASS account unlock;
grant sysdg, sysbackup to gsmrootuser;
alter user gsmuser account unlock;
alter user gsmuser identified by $GSM_PASS;
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
set serveroutput on
spool $ORACLE_BASE/validateShard.out
execute DBMS_GSM_FIX.validateShard
spool off
--alter system set events 'immediate trace name GWM_TRACE level 7';
--grant inherit privileges on user SYS to GSMADMIN_INTERNAL;
EOF

       if [ -f $ORACLE_BASE/validateShard.out ]
     then shardStatus=$(egrep -i "ERROR|WARNING" $ORACLE_BASE/validateShard.out | wc -l)

            if [ $shardStatus -gt 0 ]
          then echo "#############################################"
               echo " validateShard produced one or more errors or"
               echo " warnings. Check the output of the procedure."
               echo "#############################################"
               echo " "
          fi
     fi   # End of shard validation results
fi

# Remove temporary response file
rm $ORACLE_BASE/dbca.rsp

# Moved the moveFiles/symLinkFiles functionality from runOracle.sh to here to preserve the files and create the links properly.

  if [ ! -d $ORACLE_BASE/oradata/dbconfig/$ORACLE_SID ]; then
     mkdir -p $ORACLE_BASE/oradata/dbconfig/$ORACLE_SID/
fi;

mv $ORACLE_HOME/dbs/spfile$ORACLE_SID.ora $ORACLE_BASE/oradata/dbconfig/$ORACLE_SID/
mv $ORACLE_HOME/dbs/orapw$ORACLE_SID $ORACLE_BASE/oradata/dbconfig/$ORACLE_SID/
mv $ORACLE_HOME/network/admin/sqlnet.ora $ORACLE_BASE/oradata/dbconfig/$ORACLE_SID/
mv $ORACLE_HOME/network/admin/listener.ora $ORACLE_BASE/oradata/dbconfig/$ORACLE_SID/
mv $ORACLE_HOME/network/admin/tnsnames.ora $ORACLE_BASE/oradata/dbconfig/$ORACLE_SID/

# oracle user does not have permissions in /etc, hence cp and not mv
cp /etc/oratab $ORACLE_BASE/oradata/dbconfig/$ORACLE_SID/

  if [ ! -L $ORACLE_HOME/dbs/spfile$ORACLE_SID.ora ]
then   if [ -f $ORACLE_HOME/dbs/spfile$ORACLE_SID.ora ]
     then mv $ORACLE_HOME/dbs/spfile$ORACLE_SID.ora $ORACLE_BASE/oradata/dbconfig/$ORACLE_SID/
     fi;
     ln -s $ORACLE_BASE/oradata/dbconfig/$ORACLE_SID/spfile$ORACLE_SID.ora $ORACLE_HOME/dbs/spfile$ORACLE_SID.ora
fi;

  if [ ! -L $ORACLE_HOME/dbs/orapw$ORACLE_SID ]
then   if [ -f $ORACLE_HOME/dbs/orapw$ORACLE_SID ]
     then mv $ORACLE_HOME/dbs/orapw$ORACLE_SID $ORACLE_BASE/oradata/dbconfig/$ORACLE_SID/
     fi;
     ln -s $ORACLE_BASE/oradata/dbconfig/$ORACLE_SID/orapw$ORACLE_SID $ORACLE_HOME/dbs/orapw$ORACLE_SID
fi;

  if [ ! -L $ORACLE_HOME/network/admin/sqlnet.ora ]
then   if [ -f $ORACLE_HOME/network/admin/sqlnet.ora ]
     then mv $ORACLE_HOME/network/admin/sqlnet.ora $ORACLE_BASE/oradata/dbconfig/$ORACLE_SID/
     fi;
     ln -s $ORACLE_BASE/oradata/dbconfig/$ORACLE_SID/sqlnet.ora $ORACLE_HOME/network/admin/sqlnet.ora
fi;

  if [ ! -L $ORACLE_HOME/network/admin/listener.ora ]
then   if [ -f $ORACLE_HOME/network/admin/listener.ora ]
     then mv $ORACLE_HOME/network/admin/listener.ora $ORACLE_BASE/oradata/dbconfig/$ORACLE_SID/
     fi;
     ln -s $ORACLE_BASE/oradata/dbconfig/$ORACLE_SID/listener.ora $ORACLE_HOME/network/admin/listener.ora
fi;

  if [ ! -L $ORACLE_HOME/network/admin/tnsnames.ora ]
then   if [ -f $ORACLE_HOME/network/admin/tnsnames.ora ]
     then mv $ORACLE_HOME/network/admin/tnsnames.ora $ORACLE_BASE/oradata/dbconfig/$ORACLE_SID/
     fi;
     ln -s $ORACLE_BASE/oradata/dbconfig/$ORACLE_SID/tnsnames.ora $ORACLE_HOME/network/admin/tnsnames.ora
fi;

# oracle user does not have permissions in /etc, hence cp and not ln
  if [ -f $ORACLE_BASE/oradata/dbconfig/$ORACLE_SID/oratab ]
then cp $ORACLE_BASE/oradata/dbconfig/$ORACLE_SID/oratab /etc/oratab
fi;

# End of moveFiles/symLinkFiles component

echo " "
echo "#############################################"
echo "End of database changes for catalog/shard DBs"
echo "#############################################"
echo " "

# Begin changes under GSM home:

# If this database is the Catalog, create the configuration:
  if [[ "$SHARD_ROLE" = "CATALOG" ]]
then echo "###############################################"
     echo " Performing Shard Database Configurations "
     echo "###############################################"
     echo " "
     echo " Waiting for shards to come online..."
     # The shards are online once login to the CDB as gsmrootuser succeeds on all shards.
     # Shard database creation may not begin until all databases are up. If this is a Data
     # Guard configuration, all standby databases must be in managed recover/read only mode.

      for SHARD_SID in $(cat $ORACLE_BASE/scripts/shard.conf | cut -d: -f1)
       do
          check=
          while [[ ! $check =~ 1$ ]]
             do
                check=$(echo "select 1 from dual;" | $ORACLE_HOME/bin/sqlplus -S gsmrootuser/$GSM_PASS@$SHARD_SID) 2>/dev/null
                  if ! [[ $check =~ 1$ ]]
                then echo "Shard $SHARD_SID is not online; sleeping."
                     sleep 60
                else echo "Shard $SHARD_SID is online."
                     shardcheck=$((shardcheck+1))
                fi
           done
     done
     $ORACLE_BASE/$CREATE_SDB_FILE > $ORACLE_BASE/createSDB.out
     echo "####################################"
     echo " Results of shard database creation:"
     echo "####################################"
     echo " "
     cat $ORACLE_BASE/createSDB.out

else # SHARD_ROLE is not CATALOG
     # Start the scheduler agent
     # Verify that the shard catalog database setup is complete
     catcheck=
     while [[ ! $catcheck =~ 1$ ]]
        do
           catcheck=$(echo "select 1 from dual;" | $ORACLE_HOME/bin/sqlplus -S $SDB_ADMIN/$SDB_PASS@$CATALOG_SID) 2>/dev/null
             if ! [[ $catcheck =~ 1$ ]]
           then echo "Shard $CATALOG_SID is not online; sleeping."
                sleep 60
           else echo "Catalog at $CATALOG_SID is online."
           fi
      done

     . oraenv <<< $ORACLE_SID
     echo $SDB_PASS | $ORACLE_HOME/bin/schagent -registerdatabase $CATALOG_HOST 8080
     $ORACLE_HOME/bin/schagent -start
     $ORACLE_HOME/bin/schagent -status
fi
