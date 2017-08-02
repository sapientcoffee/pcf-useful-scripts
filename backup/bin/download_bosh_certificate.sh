#!/bin/bash

backup_script_dir=$(dirname $0)

source $backup_script_dir/../config/backup.conf
source $backup_script_dir/functions.sh

echo "Please put you OpsMan VM admin password"
scp ${CFOPS_OM_USER}@${CFOPS_HOST}:/var/tempest/workspaces/default/root_ca_certificate $backup_script_dir/../config/root_ca_certificate
