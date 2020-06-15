#!/bin/bash
# LICENSE UPL 1.0
#
# Since: May 2019
# Author: oracle.sean@gmail.com
# Description: Sets up the unix environment for GSM installation.
# 
# Setup filesystem for GSM
# ------------------------------------------------------------
mkdir -p $GSM_HOME && \
chown -R oracle:dba $GSM_HOME && \
rm -rf /var/cache/yum 
