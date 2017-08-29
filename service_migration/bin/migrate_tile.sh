#!/usr/bin/env bash

set -e # bail out early if any command fails
set -u # fail if we hit unset variables
set -o pipefail # fail if any component of any pipe fails

# Usually our workspace is in ~/workspace -- but not on machines.
: "${WORKSPACE:="$HOME/workspace"}"
script_dir=$(dirname $0)

# Credentials File
source $script_dir/../config/creds.conf

# set env var DEBUG to 1 to enable debugging
[[ -z "${DEBUG:-""}" ]] || set -x

bold=$(tput bold)
normal=$(tput sgr0)

main() {
    # Ensure tile name is passed as part of the command execution
    product_delete=$1; shift
    
    # Check that the restore data exists on the server

    # Collect Required information for script
    info "Collecting data for ${product_delete}"
    tile_guid=$(aom curl --path /api/v0/staged/products | jq  '.[].guid | match("'${product_delete}'.*")' | jq '.string' | xargs)
    product_version=$(aom curl --path /api/v0/available_products | jq '.[] | select(.name=="'$product_delete'") | .product_version' | xargs)
    success "The GUID for ${product_delete} is ${tile_guid} running version ${product_version}"

    # Delete tile from Opsman if RMQ or MySQL, Redis can be skipped - ADD TO NEW SCRIPT
    aom curl -x DELETE -p /api/v0/staged/products/${tile_guid}
    success "The ${product_delete} tile has been unstaged"
    # Apply changes
    info "Apply changes to remove the tile installation"
    aom apply-changes
    success "Tile removed"
    
    # Readd tile if its been deleted 
    aom stage-product -p ${product_delete} -v ${product_version}

    # Apply Tile configuration  - NOT WORKING NEEDS TO BE INVESTIGATED FURTHUR 
    product_configuration=$(cat ${WORKING_DIR}/${tile_guid}_export.json)
    aom configure-product --product-name ${product_delete} --product-properties ${product_configuration}

    # Apply changes 
    aom apply-changes
}

############
## Functions
############
aom(){
    om --skip-ssl-validation \
    --target https://${OPSMAN_TARGET} \
    --username ${OPSMAN_USERNAME} \
    --password ${OPSMAN_PASSWORD} \
    "$@"
}

log_date() {
    return $(date "+%Y%m%d %H%M%S")
}

info() {
    #echo "$(date) - INFO  - $@"
	printf " [ \033[00;34m..\033[0m ] $(date) - INFO - $@\n"
}

debug() {
	#echo "$(date) - DEBUG  - $@"
	printf "\r [ \033[0;33m?\033[0m ]$(date) - DEBUG - $@\n "
}

success () {
    printf "\r\033[2K [ \033[00;32mOK\033[0m ] $(date) - SUCCESS - $1\n"
}

match () {
    printf "\r\033[2K[ \033[00;32mMATCH\033[0m ] $1\n"
}

error() {
    (>&2 echo "$(date) - ERROR - $@")
}

panic() {
    error $@
    exit 1
}



main "$@"