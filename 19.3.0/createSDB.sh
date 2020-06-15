export ORACLE_HOME=$GSM_HOME
export LD_LIBRARY_PATH=$GSM_HOME/lib
export PATH=$GSM_HOME:$PATH

echo "##################################################"
echo " Creating the shard database catalog on $ORACLE_PDB"
echo "##################################################"
echo " "

$GSM_HOME/bin/gdsctl << EOF
create shardcatalog -database $ORACLE_PDB -user $SDB_ADMIN/$SDB_PASS -sharding user -region $GSM_REGION -protectmode maxperformance -sdb $SHARD_DBNAME -configname $SHARD_DBNAME
connect $SDB_ADMIN/$SDB_PASS@$ORACLE_PDB
add gsm -gsm $SHARD_DIRECTOR -catalog $ORACLE_PDB -pwd $SDB_PASS -listener $GSM_PORT -region $(echo $GSM_REGION | cut -d, -f1)
start gsm -gsm $SHARD_DIRECTOR
EOF

echo "##################################################"
echo " Creating shardspaces and shards on $ORACLE_PDB"
echo "##################################################"
echo " "

$GSM_HOME/bin/gdsctl << EOF
connect $SDB_ADMIN/$SDB_PASS@$ORACLE_PDB
add shardspace -shardspace NORTHAMERICA
add shardspace -shardspace EUROPE
add shardspace -shardspace ASIAPACIFIC
config shardspace
add cdb -connect SH11:1521/SH11 -pwd $GSM_PASS
add cdb -connect SH12:1521/SH12 -pwd $GSM_PASS
add cdb -connect SH13:1521/SH13 -pwd $GSM_PASS
config cdb
add shard -connect SH11:1521/SH11PDB1 -pwd $GSM_PASS -shardspace NORTHAMERICA -deploy_as primary -region NA   -cdb SH11
add shard -connect SH12:1521/SH12PDB1 -pwd $GSM_PASS -shardspace EUROPE       -deploy_as primary -region EU   -cdb SH12
add shard -connect SH13:1521/SH13PDB1 -pwd $GSM_PASS -shardspace ASIAPACIFIC  -deploy_as primary -region APAC -cdb SH13
config shard
deploy
config
config vncr
databases
add service -service OLTP_RW_SVC -role primary
start service -service OLTP_RW_SVC
config service
status service
config shard -shard SH11_SH11PDB1
config shard -shard SH12_SH12PDB1
config shard -shard SH13_SH13PDB1
EOF

echo "##################################################"
echo " Creating shard database objects in $ORACLE_PDB"
echo "##################################################"
echo " "

export ORACLE_HOME=$ORACLE_HOME
export LD_LIBRARY_PATH=$ORACLE_HOME/lib
export PATH=$ORACLE_HOME:$PATH

source /usr/local/bin/oraenv <<< $ORACLE_SID
$ORACLE_HOME/bin/sqlplus / as sysdba << EOF
alter session set container=$SHARD_DB;
alter session enable shard ddl;
create user app identified by app;
grant all privileges to app;
grant gsmadmin_role to app;
grant select_catalog_role to app;
grant connect, resource to app;
grant execute on dbms_crypto to app;
grant dba to app;
create tablespace NORTHAMERICA_TS in shardspace NORTHAMERICA datafile size 50m extent management local segment space management auto;
create tablespace EUROPE_EU_TS    in shardspace EUROPE       datafile size 50m extent management local segment space management auto;
create tablespace EUROPE_UK_TS    in shardspace EUROPE       datafile size 50m extent management local segment space management auto;
create tablespace APAC_TS         in shardspace ASIAPACIFIC  datafile size 50m extent management local segment space management auto;
EOF

echo "##################################################"
echo " Reporting shard status for $ORACLE_PDB"
echo "##################################################"
echo " "

export ORACLE_HOME=$GSM_HOME
export LD_LIBRARY_PATH=$GSM_HOME/lib
export PATH=$GSM_HOME:$PATH
$GSM_HOME/bin/gdsctl << EOF > $ORACLE_BASE/shard_status.out
set gsm -gsm $SHARD_DIRECTOR
show ddl
show ddl -failed_only
validate
validate catalog
EOF

