#!/usr/bin/env bash

# use set -e instead of #!/bin/bash -e in case we're
# called with `bash ~/bin/scriptname`
set -e # bail out early if any command fails
set -u # fail if we hit unset variables
set -o pipefail # fail if any component of any pipe fails

# Usually our workspace is in ~/workspace -- but not on
# all on-call machines.
: "${WORKSPACE:="$HOME/workspace"}"
script_dir=$(dirname $0)

# Credentials File
source $script_dir/../config/creds.conf

# set env var DEBUG to 1 to enable debugging
[[ -z "${DEBUG:-""}" ]] || set -x

bold=$(tput bold)
normal=$(tput sgr0)

# Script assumes logged in at the CF CLI alreday 

main() {
    # Check required software is installed
    check_dependancies
    success "Dependancies met"
    
    # List all the service instances that do not have a bound app
    spaces=$(cf curl /v2/spaces | jq -r -c '.resources[]')
    for space in ${spaces} 
    do
        space_guid=$(echo ${space} | jq -r '.metadata.guid')
        space_name=$(echo ${space} | jq -r '.entity.name')
        org_guid=$(echo ${space} | jq -r '.entity.organization_guid')

        summary=$(cf curl /v2/spaces/${space_guid}/summary | jq -r -c '.services[]')
        for summary in ${summary}
        do
            service_name=$(echo ${summary} | jq -r '.name')
            bound_app_count=$(echo ${summary} | jq -r '.bound_app_count')

            if [[ "${bound_app_count}" == "0" ]]
            then
                org_name=$(cf curl /v2/organizations | jq '.resources[] | select(.metadata.guid=="'${org_guid}'") | .entity.name' | xargs)
                warn "The service named ${service_name} has no bound apps in Org: ${org_name}, Space: ${space_name}"
            fi
        done
    done

    # Capture the current status on the platfrom so that it can be compared post migration
    info "Capture status of the foundation to ${WORKING_DIR}"
    initial_pcfstatus="${WORKING_DIR}/pcfstatus.yml"
    apcfstatus -k es > ${initial_pcfstatus}
    # Ensure that the export yml file is not empty
    dir_size_greater_than_threshold ${WORKING_DIR}/pcfstatus.yml 0
    ret=$?
    [[ "$ret" == 0 ]] || panic "Backup failed. Files seem to be empty."
    success "Status Captured"

    # Export entire OpsMan configuration 
    info "Exporting ALL opsman configuration - can take over 10 minutes to complete ..."
    aom export-installation -o ${WORKING_DIR}/opsman.json
    success "Opsman installation settings exported"
    
    # Work out what tiles are installed and export the configuration
    tiles=$(aom curl --path /api/v0/available_products | jq -c -r '.[].name')
    for tile in ${tiles} 
    do
        info "Found ${tile}, exporting the configuration"
        tile_guid=$(om curl --path /api/v0/staged/products | jq  '.[].guid | match("'${tile}'.*")' | jq '.string' | xargs)
        #tile_guid=$(aom curl --path /api/v0/staged/products | jq '.[] | select(.guid | startswith("${tile}"))' | jq '.guid' | xargs)

        output="${WORKING_DIR}/${tile_guid}_export.json"
        aom curl -p /api/v0/staged/products/${tile_guid}/properties > ${output}
        success "${tile} saved to ${output}"
    done
}

############
## Functions

aom(){
    om --skip-ssl-validation \
    --target https://${OPSMAN_TARGET} \
    --username ${OPSMAN_USERNAME} \
    --password ${OPSMAN_PASSWORD} \
    "$@"
}

apcfstatus() {
    CF_USERNAME=${CF_USERNAME} \
    CF_PASSWORD=${CF_PASSWORD} \
    pcfstatus \
    --cf-api-url https://${CF_API_TARGET} \
    $@
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

warn () {
    printf "\r\033[2K[ \033[00;32mWARN\033[0m ] $1\n"
}

error() {
    (>&2 echo "$(date) - ERROR - $@")
}

panic() {
    error $@
    exit 1
}

dir_size_greater_than_threshold() {
    # arg1: file_to_check (can also be a dir)
    # arg2: threshold in bytes

	file_to_check=$1
	threshold=$2

	files_lower_exist=0

	# check that all files are greater than 1
	for f in $(ls -1 $file_to_check); do
		# populate full path, if dir is provided
		if [ -f $file_to_check ]; then
			path_of_file=$f
		else
			path_of_file="$file_to_check/$f"
		fi

		file_size=$(du -s $path_of_file | awk '{print $1}')

		if [ "$file_size" -le "$threshold" ]; then		
			echo "File '$path_of_file' is smaller than defined threshold of '$threshold'"
			files_lower_exist=1
		fi
	done

	if [ "$files_lower_exist" -eq 1 ]; then
		return 2
	fi

	return 0
}

check_dependancies() {
    if [[ "$(which jq)X" == "X" ]]
    then
        echo "Please install jq"
        exit 1
    fi
    if [[ "$(which om)X" == "X" ]]
    then
        echo "Please install jq"
        exit 1
    fi
    if [[ "$(which cf)X" == "X" ]]
    then
        echo "Please install cf"
        exit 1
    fi
    if [[ "$(which pcfstatus)X" == "X" ]]
    then
        echo "Please install jq"
        exit 1
    fi
}

main "$@"