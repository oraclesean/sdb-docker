#!/bin/bash
# LICENSE UPL 1.0
#
# Copyright (c) 1982-2018 Oracle and/or its affiliates. All rights reserved.
#
# Since: December, 2016
# Author: oracle.sean@gmail.com
# Description: Sets up the unix environment for GSM installation.
# 
# DO NOT ALTER OR REMOVE COPYRIGHT NOTICES OR THIS HEADER.
# 

# Check whether ORACLE_BASE is set
if [ "$ORACLE_BASE" == "" ]; then
   echo "ERROR: ORACLE_BASE has not been set!"
   echo "You have to have the ORACLE_BASE environment variable set to a valid value!"
   exit 1;
fi;

# Check whether GSM_HOME is set
if [ "$GSM_HOME" == "" ]; then
   echo "ERROR: GSM_HOME has not been set!"
   echo "You have to have the GSM_HOME environment variable set to a valid value!"
   exit 1;
fi;

# Replace place holders
# ---------------------
sed -i -e "s|###ORACLE_BASE###|$ORACLE_BASE|g" $INSTALL_DIR/$GSM_RSP && \
sed -i -e "s|###GSM_HOME###|$GSM_HOME|g" $INSTALL_DIR/$GSM_RSP

# Install Oracle binaries
cd $INSTALL_DIR         && \
unzip $GSM_INSTALL_FILE && \
rm $GSM_INSTALL_FILE    && \
$INSTALL_DIR/gsm/runInstaller -silent -ignorePrereqFailure -ignoreSysPrereqs -waitforcompletion -responseFile $INSTALL_DIR/$GSM_RSP 2>/dev/null || exit 0 && \
cd $HOME

# Remove unneeded components:
# Temp location
rm -rf /tmp/* && \
# Network tools help
rm -rf $GSM_HOME/network/tools/help && \
# Database migration assistant
rm -rf $GSM_HOME/dmu && \
# Support tools
rm -rf $GSM_HOME/suptools && \
# Database files directory
rm -rf $INSTALL_DIR/gsm
