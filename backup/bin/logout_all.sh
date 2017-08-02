#!/bin/bash

BACKUP_SCRIPT_DIR=$(dirname $0)

# backup configuration
source $BACKUP_SCRIPT_DIR/backup.conf
source $BACKUP_SCRIPT_DIR/functions.sh

# authenticate against uaa
export UAA_TOKEN=$(uaa_authenticate $CFOPS_CLIENT_ID $CFOPS_CLIENT_SECRET)

# logout all users
om_logout
