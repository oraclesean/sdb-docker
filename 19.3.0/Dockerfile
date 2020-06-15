# LICENSE UPL 1.0
#
# Copyright (c) 1982-2018 Oracle and/or its affiliates. All rights reserved.
#
# ORACLE DOCKERFILES PROJECT
# --------------------------
# This is the Dockerfile for Oracle Database 19c with GSM
# Modified from the Oracle Database 19c Dockerfile
# 
# REQUIRED FILES TO BUILD THIS IMAGE
# ----------------------------------
# (1) db_home.zip
#     Download Oracle Database 19c Enterprise Edition or Standard Edition 2 for Linux x64
#     from http://www.oracle.com/technetwork/database/enterprise-edition/downloads/index.html
# (2) gsm.zip
#     Download Oracle Global Service Manager for Linux x64
#     from https://www.oracle.com/technetwork/database/enterprise-edition/downloads/oracle19c-linux-5462157.html
#
# HOW TO BUILD THIS IMAGE
# -----------------------
# Put all downloaded files in the same directory as this Dockerfile
# Run: 
#      $ docker build -t oracle/database/gsm:19.3.0-${EDITION} . 
#
# Pull base image
# ---------------
FROM oraclelinux:7-slim as base

# Maintainer
# ----------
MAINTAINER Sean Scott <oracle.sean@gmail.com>

# Environment variables required for this build (do NOT change)
# Added entries are: GSM_HOME, GSM_INSTALL_FILE, GSM_RSP, 
#                    SETUP_GSM_FILE, INSTALL_GSM_BINARIES_FILE
# -------------------------------------------------------------
ENV ORACLE_BASE=/opt/oracle \
    GSM_HOME=/opt/oracle/product/19c/gsmhome_1 \
    ORACLE_HOME=/opt/oracle/product/19c/dbhome_1 \
    INSTALL_DIR=/opt/install \
    GSM_INSTALL_FILE="LINUX.X64_193000_gsm.zip" \
    INSTALL_FILE_1="LINUX.X64_193000_db_home.zip" \
    GSM_RSP="gsm_inst.rsp" \
    INSTALL_RSP="db_inst.rsp" \
    CONFIG_RSP="dbca.rsp.tmpl" \
    PWD_FILE="setPassword.sh" \
    RUN_FILE="runOracle.sh" \
    START_FILE="startDB.sh" \
    CREATE_DB_FILE="createDB.sh" \
    CREATE_SDB_FILE="createSDB.sh" \
    SETUP_LINUX_FILE="setupLinuxEnv.sh" \
    SETUP_GSM_FILE="setupGSMEnv.sh" \
    CHECK_SPACE_FILE="checkSpace.sh" \
    CHECK_DB_FILE="checkDBStatus.sh" \
    USER_SCRIPTS_FILE="runUserScripts.sh" \
    INSTALL_GSM_BINARIES_FILE="installGSMBinaries.sh" \
    INSTALL_DB_BINARIES_FILE="installDBBinaries.sh"

# Use second ENV so that variable get substituted
# Add the GSM_HOME to the PATH
ENV PATH=$ORACLE_HOME/bin:$GSM_HOME/bin:$ORACLE_HOME/OPatch/:/usr/sbin:/home/oracle/bin:$PATH \
    LD_LIBRARY_PATH=$ORACLE_HOME/lib:$GSM_HOME/lib:/usr/lib \
    CLASSPATH=$ORACLE_HOME/jlib:$ORACLE_HOME/rdbms/jlib:$GSM_HOME/jlib

# Copy files needed during both installation and runtime
# Add the GSM and SDB files
# ------------------------------------------------------
COPY $SETUP_GSM_FILE $CHECK_SPACE_FILE $SETUP_LINUX_FILE $INSTALL_DIR/
COPY $RUN_FILE $START_FILE $CREATE_DB_FILE $CONFIG_RSP $PWD_FILE $CHECK_DB_FILE $USER_SCRIPTS_FILE $ORACLE_BASE/
COPY $CREATE_SDB_FILE $ORACLE_BASE/

RUN chmod ug+x $INSTALL_DIR/*.sh && \
    sync && \
    $INSTALL_DIR/$CHECK_SPACE_FILE && \
    $INSTALL_DIR/$SETUP_LINUX_FILE && \
# Include the GSM setup
    $INSTALL_DIR/$SETUP_GSM_FILE && \
    rm -rf $INSTALL_DIR

#############################################
# -------------------------------------------
# Start new stage for installing GSM
# -------------------------------------------
#############################################

FROM base as gsmbuild

# Copy GSM install file
COPY --chown=oracle:dba $GSM_INSTALL_FILE $GSM_RSP $INSTALL_GSM_BINARIES_FILE $INSTALL_DIR/

# Install GSM software binaries
USER oracle
RUN chmod ug+x $INSTALL_DIR/*.sh && \
    sync && \
    $INSTALL_DIR/$INSTALL_GSM_BINARIES_FILE

#############################################
# -------------------------------------------
# Start new stage for installing the database
# -------------------------------------------
#############################################

FROM base AS builder

ARG DB_EDITION

# Copy GSM installation
COPY --chown=oracle:dba --from=gsmbuild $GSM_HOME $GSM_HOME
# Copy DB install file
COPY --chown=oracle:dba $INSTALL_FILE_1 $INSTALL_RSP $INSTALL_DB_BINARIES_FILE $INSTALL_DIR/

# Install DB software binaries
USER oracle
RUN chmod ug+x $INSTALL_DIR/*.sh && \
    sync && \
    $INSTALL_DIR/$INSTALL_DB_BINARIES_FILE $DB_EDITION

#############################################
# -------------------------------------------
# Start new layer for database runtime
# -------------------------------------------
#############################################

FROM base

USER oracle
COPY --chown=oracle:dba --from=builder $ORACLE_BASE $ORACLE_BASE

USER root
RUN $ORACLE_BASE/oraInventory/orainstRoot.sh && \
    $ORACLE_HOME/root.sh && \
# Run the GSM root script
    $GSM_HOME/root.sh

USER oracle
WORKDIR /home/oracle

VOLUME ["$ORACLE_BASE/oradata"]
EXPOSE 1521 5500 1571 1572
HEALTHCHECK --interval=1m --start-period=15m \
   CMD "$ORACLE_BASE/$CHECK_DB_FILE" >/dev/null || exit 1

# Define default command to start Oracle Database. 
CMD exec $ORACLE_BASE/$RUN_FILE

