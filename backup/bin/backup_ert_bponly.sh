#!/bin/bash

backup_script_dir=$(dirname $0)

# backup configuration
source $backup_script_dir/../config/backup.conf
source $backup_script_dir/functions.sh

# authenticate against uaa
uaac target https://${CFOPS_HOST}/uaa
export UAA_TOKEN=$(uaa_authenticate $CFOPS_CLIENT_ID $CFOPS_CLIENT_SECRET)
success "Authntication Token Acquired" 

# create a backup dir
current_date=$(date "+%Y%m%d")
backup_parent_dir="${BACKUP_DATA_DIR}/ert_bponly"
backup_dir="${backup_parent_dir}/$current_date"
mkdir -p $backup_dir

# before running cfops make sure that we are logged out
info "Logging out users from OpsMan..."
om_logout_others

# run backup
LOG_LEVEL=debug cfops backup -d $backup_dir -tile elastic-runtime -nfs bp
ret=$?
[[ "$ret" == 0 ]] || panic "Backup failed. RETURN CODE '$ret' see details above."

# logout backup user
info "Logging out OpsMan backup user"
om_logout

# if backup was successful test if files are greater then 0
dir_size_greater_than_threshold $backup_dir 0
ret=$?
[[ "$ret" == 0 ]] || panic "Backup failed. Files seem to be empty."
success "Backup Size NOT zero" 

exit $ret
