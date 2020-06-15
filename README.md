# sdb-docker

Files for building an Oracle sharded database in Docker, allowing users to more easily experiemnt with Oracle SDB technology.

An Oracle shard database requires a catalog database and multiple shard databases. Each shard is an Active Data Guard configuration, consisting of a primary/standby. To have a SDB with three shards would typically require seven databases, three primary, three standby, and a catalog database. Running this in VM is a costly proposition but it can be done in Docker rather easily, provided the system has adequate memory.

## Setup

Set Docker's memory limit in GB to ((8 * shard_count) * 4)
For a two shard environment this is 20G.
For a three shard environment this is 28G.

## Prerequisites
This repo is built on the Oracle Docker repository: https://github.com/oracle/docker-images

Download the following files from Oracle OTN:
```
LINUX.X64_193000_gsm.zip
LINUX.X64_193000_db_home.zip
```

## Set the environment
The ORA_DOCKER_DIR is the location of the existing docker-images directory. The ORADATA_VOLUME is for persisting data for the databases. Each database will inhabit a subdirectory of ORADATA_VOLUME based on the database unique name.
```
export COMPOSE_YAML=docker-compose.yml
export DB_VERSION=19.3.0
export IMAGE_NAME=oracle/database/gsm:${DB_VERSION}-ee
export ORA_DOCKER_DIR=~/docker
export ORADATA_VOLUME=~/oradata
export SHARD_DIR=~/sdb-docker
```

## Copy the Oracle Docker files from their current location to the Shard directory:
`cp $ORA_DOCKER_DIR/docker-images/OracleDatabase/SingleInstance/dockerfiles/$DB_VERSION/* $SHARD_DIR`

## Copy the downloaded Oracle GSM and Oracle database installation files to the Shard directory:
```
cp LINUX.X64_193000_gsm.zip $SHARD_DIR/$DB_VERSION
cp LINUX.X64_193000_db_home.zip $SHARD_DIR/$DB_VERSION
```

## Navigate to the Shard directory
`cd $SHARD_DIR`

## Run the build to create the oracle/datbase/gsm:19.3.0-ee Docker image
`./buildDockerImage.gsm.sh -v 19.3.0 -e`

## Run compose (detached)
`docker-compose up -d`

## Tail the logs
`docker-compose logs -f`



# OPTIONAL STEPS
## Database configurations
Customize a configuration file for setting up the contaner hosts using the following format if the existing config_dataguard.lst (for a three-shard database) does not meet your needs. This file is used for automated setup of the environment.

The container name is the DB_UNIQUE_NAME.
The pluggable database is ${ORACLE_SID}PDB1.

```
cat << EOF > $SHARD_DIR/config_dataguard.lst
# Container | ID | Role   | DG Config | SID  | DG_TARGET | Oracle Pass | Shard Role | GSM pass | SDB Admin | SDB pass | Shard DB | Shard DB Name | Shard Dir | Port | Region
SH00        | 0  | PRIMARY| NONE      | SH00 |           | oracle      | CATALOG    | oracle   | sdbadmin  | oracle   | SH00PDB1 | shardcat      | sharddir1 | 1571 | na,eu,asia
SH11        | 1  | PRIMARY| SH1       | SH11 | SH21      | oracle      |            | oracle   | sdbadmin  | oracle   |          |               |           |      | na
SH21        | 2  | STANDBY| SH1       | SH11 | SH11      | oracle      |            |          |           |          |          |               |           |      | na
SH12        | 3  | PRIMARY| SH2       | SH12 | SH22      | oracle      | DIRECTOR   | oracle   | sdbadmin  | oracle   | SH00PDB1 |               | sharddir2 | 1572 | eu
SH22        | 4  | STANDBY| SH2       | SH12 | SH12      | oracle      |            |          |           |          |          |               |           |      | eu
SH13        | 5  | PRIMARY| SH3       | SH13 | SH23      | oracle      |            | oracle   | sdbadmin  | oracle   |          |               |           |      | asia
SH23        | 6  | STANDBY| SH3       | SH13 | SH13      | oracle      |            |          |           |          |          |               |           |      | asia
EOF
```

## Docker compose file, TNS configuration
If using a custom dataguard configuration (above) there will need to be changes to the TNS configuration and Docker compose file.

### Create a docker-compose file and build tnsnames.ora, listener.ora files
```
# Initialize the files:
cat << EOF > $COMPOSE_YAML
version: '3'
services: 
EOF

cat << EOF > $SHARD_DIR/tnsnames.ora
# tnsnames.ora extension for sharding demo
EOF

# Populate the docker-compose.yml file:
egrep -v "^$|^#" $SHARD_DIR/config_dataguard.lst | sed -e 's/[[:space:]]//g' | sort | while IFS='|' read CONTAINER_NAME CONTAINER_ID ROLE DG_CONFIG ORACLE_SID DG_TARGET ORACLE_PWD SHARD_ROLE GSM_PASS SDB_ADMIN SDB_PASS SHARD_DB SHARD_DBNAME SHARD_DIRECTOR GSM_PORT GSM_REGION
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
      SDB_ADMIN: $SDB_ADMIN
      SDB_PASS: $SDB_PASS
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

# Write the tnsnames.ora entry:
cat << EOF >> $SHARD_DIR/tnsnames.ora
$CONTAINER_NAME=
(DESCRIPTION =
  (ADDRESS = (PROTOCOL = TCP)(HOST = $CONTAINER_NAME)(PORT = 1521))
  (CONNECT_DATA =
    (SERVER = DEDICATED)
    (SERVICE_NAME = $ORACLE_SID)
  )
)
EOF

done
```
# Cleanup
## To stop compose, remove any existing image and prune the images:
```
docker-compose down
docker rmi oracle/database/gsm:19.3.0-ee
docker image prune <<< y
```

## Clear out the ORADATA volume
```
if [[ "$ORADATA_VOLUME" ]] && [ -d "$ORADATA_VOLUME" ]
  then rm -Rf $ORADATA_VOLUME/SH*
fi
#rm -Rf ~/oradata/SH*
```
