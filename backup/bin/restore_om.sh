#!/bin/bash

backup_script_dir=$(dirname $0)

# backup configuration
source $backup_script_dir/../config/backup.conf
source $backup_script_dir/functions.sh

# authenticate against uaa
#uaac target https://${CFOPS_HOST}/uaa
#export UAA_TOKEN=$(uaa_authenticate $CFOPS_CLIENT_ID $CFOPS_CLIENT_SECRET)

# create a backup dir
current_date=$(date "+%Y%m%d")
backup_dir=$1

# before running cfops make sure that we are logged out
#om_logout_others

LOG_LEVEL=debug cfops restore -d $backup_dir -tile ops-manager
ret=$?
[[ "$ret" == 0 ]] || panic "Restore failed. RETURN CODE '$ret' see details above."

exit $ret
