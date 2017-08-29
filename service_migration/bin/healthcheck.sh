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

main() {

    option=$1; shift
    if [[ "${option}" == "status" ]] 
    then
        # Check status of current configuration compared to original state
        initial_pcfstatus="${WORKING_DIR}/pcfstatus.yml"
        apcfstatus -k cs --state-file ${initial_pcfstatus}
    elif [[ "${option}" == "p-redis" ]]
    then
        echo "Running P-Redis Smoke Tests"
        bosh -e gcp -d p-redis-5f4ad9e4435bed1dec77 run-errand smoke-tests
        
        # run-errand smoke-tests --download-logs --logs-dir ~/workspace/smoke-tests-logs
    
    fi
}

############
## Functions

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