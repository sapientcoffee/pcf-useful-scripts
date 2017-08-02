#!/bin/bash

backup_script_dir=$(dirname $0)

source $backup_script_dir/../config/backup.conf
source $backup_script_dir/functions.sh

#
# create OpsMan user if user exist in backup.con
#
if [ "$CFOPS_CLIENT_ID" != "" ] && [ "$CFOPS_CLIENT_SECRET" != "" ]; then
    echo "Creating OpsMan credentials"
    #
    # ask for uaa credentials
    #
    echo -n "OpsMan 'admin' password: " && read -s OPSMAN_ADMIN_PW && echo

    uaac target https://$CFOPS_HOST/uaa --skip-ssl-validation
    uaac token owner get opsman admin -s "" -p "$OPSMAN_ADMIN_PW"

    uaac client add "$CFOPS_CLIENT_ID" --authorized_grant_type client_credentials --scope opsman.admin --authorities opsman.admin --access_token_validity 43200 --refresh_token_validity 43200 -s "$CFOPS_CLIENT_SECRET"
else
    echo "Not creating OpsMan credentials. Please set CFOPS_CLIENT_ID and CFOPS_CLIENT_SECRET in backup.conf"
fi

echo " ==="

#
# create BOSH admin user if user exist in backup.conf
#
if [ "$BOSH_CLIENT" != "" ] && [ "$BOSH_CLIENT_SECRET" != "" ]; then
    echo "Creating BOSH credentials"
    #
    # ask for uaa credentials
    #
    echo -n "UAA 'login' client secret: " && read -s UAA_LOGIN_CLIENT_SECRET && echo
    echo -n "UAA 'admin' password: " && read -s UAA_ADMIN_PW && echo
    
    # target and login
    uaac target $BOSH_TARGET:8443 --skip-ssl-validation
    uaac token owner get login admin -s "$UAA_LOGIN_CLIENT_SECRET" -p "$UAA_ADMIN_PW"
    
    # create user
    uaac client add "$BOSH_CLIENT" --authorized_grant_type client_credentials --authorities bosh.admin --access_token_validity 43200 --refresh_token_validity 43200 -s "$BOSH_CLIENT_SECRET"
else
    echo "Not creating OpsMan credentials. Please set BOSH_CLIENT and BOSH_CLIENT_SECRET in backup.conf"
fi

echo " ==="
