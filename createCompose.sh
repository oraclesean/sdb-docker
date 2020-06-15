# Set variables for environment
export SHARD_DIR=~/sdb-docker
export ORADATA_VOLUME=~/oradata

# Set variables used by Docker, Compose:
export DB_VERSION=19.3.0
export COMPOSE_YAML=docker-compose.yml
export GSM_IMAGE_NAME=oracle/database/gsm:${DB_VERSION}-ee
export CATALOG_SID=$(grep "CATALOG" $SHARD_DIR/config_dataguard.lst | awk '{print $(NF-8)}')
export CATALOG_HOST=$(grep "CATALOG" $SHARD_DIR/config_dataguard.lst | awk '{print $1}')

# Create a docker-compose file and dynamically build the tnsnames.ora file
# Initialize the docker-compose file:
cat << EOF > $COMPOSE_YAML
version: '3'
services: 
EOF

# Initialize the TNS and GSM ora files:
cat << EOF > $SHARD_DIR/tnsnames.ora
# tnsnames.ora file for sharding demo
EOF
cat << EOF > $SHARD_DIR/gsm.ora
# gsm.ora file for sharding demo
EOF

# Initialize the global shard configuration
cat /dev/null > $SHARD_DIR/shard.conf

# Populate the docker-compose.yml file:
egrep -v "^$|^#" $SHARD_DIR/config_dataguard.lst | sed -e 's/[[:space:]]//g' | sort | while IFS='|' read CONTAINER_NAME CONTAINER_ID ROLE DG_CONFIG ORACLE_SID DB_UNQNAME DG_TARGET ORACLE_PWD SHARD_ROLE GSM_PASS SDB_ADMIN SDB_PASS SHARD_DB SHARD_DBNAME SHARD_DIRECTOR GSM_PORT GSM_REGION
do

# Write the Docker compose file entry:
cat << EOF >> $COMPOSE_YAML
  $CONTAINER_NAME:
    image: $GSM_IMAGE_NAME
    container_name: $CONTAINER_NAME
    hostname: $CONTAINER_NAME
    volumes:
      - "$ORADATA_VOLUME/$CONTAINER_NAME:/opt/oracle/oradata"
      - "$SHARD_DIR:/opt/oracle/scripts"
    environment:
      CONTAINER_NAME: $CONTAINER_NAME
      DG_CONFIG: $DG_CONFIG
      DG_TARGET: $DG_TARGET
      SDB_ADMIN: $SDB_ADMIN
      SDB_PASS: $SDB_PASS
      GSM_PASS: $GSM_PASS
      GSM_PORT: $GSM_PORT
      GSM_REGION: $GSM_REGION
      ORACLE_PDB: ${ORACLE_SID}PDB1
      ORACLE_PWD: $ORACLE_PWD
      ORACLE_SID: $ORACLE_SID
      DB_UNQNAME: $DB_UNQNAME
      ROLE: $ROLE
      SHARD_DB: $SHARD_DB
      SHARD_DBNAME: $SHARD_DBNAME
      SHARD_DIRECTOR: $SHARD_DIRECTOR
      SHARD_ROLE: $SHARD_ROLE
      CATALOG_SID: $CATALOG_SID
      CATALOG_HOST: $CATALOG_HOST
    ports:
      - "120$CONTAINER_ID:1521"
      - "171$CONTAINER_ID:1571"
      - "172$CONTAINER_ID:1572"

EOF

# Write a tnsnames.ora entry for each instance in the configuration file:
cat << EOF >> $SHARD_DIR/tnsnames.ora
$CONTAINER_NAME =
(DESCRIPTION =
  (ADDRESS = (PROTOCOL = TCP)(HOST = $CONTAINER_NAME)(PORT = 1521))
  (CONNECT_DATA =
    (SERVER = DEDICATED)
    (SERVICE_NAME = $ORACLE_SID)
  )
)

${CONTAINER_NAME}PDB1=
(DESCRIPTION =
  (ADDRESS = (PROTOCOL = TCP)(HOST = $CONTAINER_NAME)(PORT = 1521))
  (CONNECT_DATA =
    (SERVER = DEDICATED)
    (SERVICE_NAME = ${ORACLE_SID}PDB1)
  )
)

EOF

# Write a TNS entry for Data Guard targets
###  if [ ! -z "$DG_TARGET" ]
###then cat << EOF >> $SHARD_DIR/tnsnames.ora
###${CONTAINER_NAME}_DG =
###(DESCRIPTION =
###  (ADDRESS = (PROTOCOL = TCP)(HOST = $CONTAINER_NAME)(PORT = 1521))
###  (CONNECT_DATA =
###    (SERVER = DEDICATED)
###    (SID = $ORACLE_SID)
###  )
###)

###EOF
###fi

# Write a gsm.ora entry for each Catalog or Director instance in the configuration file:
  if [ "$SHARD_ROLE" = "CATALOG" ]
then cat << EOF >> $SHARD_DIR/gsm.ora
${ORACLE_SID}PDB1=
(configuration=
  (listener=(address=(protocol=tcp)(host=${CONTAINER_NAME})(port=${GSM_PORT})))
  (parameter_list =
    (log_level=off)
    (inbound_connect_timeout=0)
    (outbound_connect_timeout=0)
    (trace_level=off)
  )
)
EOF

# ...else add global shard name/roles to the shard list:
else echo $CONTAINER_NAME:$ORACLE_SID:$ORACLE_PDB:$DB_UNQNAME:$ROLE:$GSM_REGION >> $SHARD_DIR/shard.conf
fi

done

