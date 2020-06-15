docker-compose down
docker rmi oracle/database/gsm:19.3.0-ee
docker image prune <<< y

rm -Rf ~/oradata/SH*

# Recreate the compose file based on changes to the configuration
./createCompose.sh

# Run the build to create the oracle/datbase/gsm:19.3.0-ee Docker image
./buildDockerImage.sh -v 19.3.0 -e

# Run compose (detached)
docker-compose up -d
# Tail the logs
docker-compose logs -f
