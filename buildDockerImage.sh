#!/bin/bash
# 
# Since: April, 2016
# Author: oracle.sean@gmail.com
# Description: Build script for building Oracle GSM Docker images.
# 
# DO NOT ALTER OR REMOVE COPYRIGHT NOTICES OR THIS HEADER.
# 
# Copyright (c) 2014-2019 Oracle and/or its affiliates. All rights reserved.
# 

usage() {
  cat << EOF

Usage: buildDockerImage.sh [-o] [Docker build option]
Builds a Docker Image for Oracle Database.
  
Parameters:
   -o: passes on Docker build option

LICENSE UPL 1.0

Copyright (c) 2014-2019 Oracle and/or its affiliates. All rights reserved.

EOF

}

# Check Docker version
checkDockerVersion() {
  # Get Docker Server version
  DOCKER_VERSION=$(docker version --format '{{.Server.Version | printf "%.5s" }}')
  # Remove dot in Docker version
  DOCKER_VERSION=${DOCKER_VERSION//./}

  if [ "$DOCKER_VERSION" -lt "${MIN_DOCKER_VERSION//./}" ]; then
    echo "Docker version is below the minimum required version $MIN_DOCKER_VERSION"
    echo "Please upgrade your Docker installation to proceed."
    exit 1;
  fi;
}

##############
#### MAIN ####
##############

# Parameters
VERSION="19.3.0"
SKIPMD5=0
DOCKEROPS=""
MIN_DOCKER_VERSION="17.09"
DOCKERFILE="Dockerfile.gsm"

while getopts "hesxiv:o:" optname; do
  case "$optname" in
    "h")
      usage
      exit 0;
      ;;
    "o")
      DOCKEROPS="$OPTARG"
      ;;
    "?")
      usage;
      exit 1;
      ;;
    *)
    # Should not occur
      echo "Unknown error while processing options inside buildDockerImage.sh"
      ;;
  esac
done

checkDockerVersion

# Oracle Database Image Name
IMAGE_NAME="oracle/gsm:$VERSION"

echo "=========================="
echo "DOCKER info:"
docker info
echo "=========================="

# ################## #
# BUILDING THE IMAGE #
# ################## #
echo "Building image '$IMAGE_NAME' ..."

# BUILD THE IMAGE (replace all environment variables)
BUILD_START=$(date '+%s')
docker build --force-rm=true --no-cache=true \
       $DOCKEROPS $PROXY_SETTINGS -t $IMAGE_NAME -f $DOCKERFILE . || {
  echo ""
  echo "ERROR: Oracle GSM Docker Image was NOT successfully created."
  echo "ERROR: Check the output and correct any reported problems with the docker build operation."
  exit 1
}

# Remove dangling images (intermitten images with tag <none>)
yes | docker image prune > /dev/null

BUILD_END=$(date '+%s')
BUILD_ELAPSED=`expr $BUILD_END - $BUILD_START`

echo ""
echo ""

cat << EOF
  Oracle GSM Docker Image for version $VERSION is ready to be extended: 
    
    --> $IMAGE_NAME

  Build completed in $BUILD_ELAPSED seconds.
  
EOF

