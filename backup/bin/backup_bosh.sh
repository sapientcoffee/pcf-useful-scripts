#!/bin/bash

backup_script_dir=$(dirname $0)

source $backup_script_dir/../config/backup.conf
source $backup_script_dir/functions.sh

# create a backup dir
current_date=$(date "+%Y%m%d")
backup_parent_dir="${BACKUP_DATA_DIR}/bosh"
backup_dir="${backup_parent_dir}/$current_date"
mkdir -p $backup_dir

pushd $backup_dir

# login
bosh -n --ca-cert $BOSH_CA_CERT -t $BOSH_TARGET backup
ret=$?
[[ "$ret" == 0 ]] || panic "Backup failed. RETURN CODE '$ret' see details above."

popd

dir_size_greater_than_threshold $backup_dir 0
ret=$?
[[ "$ret" == 0 ]] || panic "Backup failed. Files seem to be empty."

exit $ret
