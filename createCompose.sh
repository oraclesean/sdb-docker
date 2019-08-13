# Set variables for environment
export SHARD_DIR=~/sdb-docker
export ORA_DOCKER_DIR=~/docker
export ORADATA_VOLUME=~/oradata

# Set variables used by Docker, Compose:
export DB_VERSION=19.3.0
export COMPOSE_YAML=docker-compose.yml
export IMAGE_NAME=oracle/database/gsm:${DB_VERSION}-ee

# Create a docker-compose file and dynamically build the tnsnames.ora file
# Initialize the docker-compose file:
cat << EOF > $COMPOSE_YAML
version: '3'
services: 
EOF

# Initialize the TNSNames file:
cat << EOF > $SHARD_DIR/tnsnames.ora
# tnsnames.ora extension for sharding demo
EOF

# Populate the docker-compose.yml file:
egrep -v "^$|^#" $SHARD_DIR/config_dataguard.lst | sed -e 's/[[:space:]]//g' | sort | while IFS='|' read CONTAINER_NAME CONTAINER_ID ROLE DG_CONFIG ORACLE_SID DG_TARGET ORACLE_PWD SHARD_ROLE GSM_PASS GDS_USER GDS_PASS SHARD_DB SHARD_DBNAME SHARD_DIRECTOR GSM_PORT GSM_REGION
do

# Write the Docker compose file entry:
cat << EOF >> $COMPOSE_YAML
  $CONTAINER_NAME:
    image: $IMAGE_NAME
    container_name: $CONTAINER_NAME
    volumes:
      - "$ORADATA_VOLUME/$CONTAINER_NAME:/opt/oracle/oradata"
      - "$SHARD_DIR:/opt/oracle/scripts"
    environment:
      CONTAINER_NAME: $CONTAINER_NAME
      DG_CONFIG: $DG_CONFIG
      DG_TARGET: $DG_TARGET
      GDS_USER: $GDS_USER
      GDS_PASS: $GDS_PASS
      GSM_PASS: $GSM_PASS
      GSM_PORT: $GSM_PORT
      GSM_REGION: $GSM_REGION
      ORACLE_PDB: ${ORACLE_SID}PDB1
      ORACLE_PWD: $ORACLE_PWD
      ORACLE_SID: $ORACLE_SID
      ROLE: $ROLE
      SHARD_DB: $SHARD_DB
      SHARD_DBNAME: $SHARD_DBNAME
      SHARD_DIRECTOR: $SHARD_DIRECTOR
      SHARD_ROLE: $SHARD_ROLE
    ports:
      - "120$CONTAINER_ID:1521"
      - "171$CONTAINER_ID:1571"
      - "172$CONTAINER_ID:1572"

EOF

# Write a tnsnames.ora entry for each instance in the configuration file:
cat << EOF >> $SHARD_DIR/tnsnames.ora
$CONTAINER_NAME=
(DESCRIPTION =
  (ADDRESS = (PROTOCOL = TCP)(HOST = $CONTAINER_NAME)(PORT = 1521))
  (CONNECT_DATA =
    (SERVER = DEDICATED)
    (SID = $ORACLE_SID)
  )
)
EOF

done

