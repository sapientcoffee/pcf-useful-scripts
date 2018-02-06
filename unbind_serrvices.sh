#!/usr/bin/env bash

# use set -e instead of #!/bin/bash -e in case we're
# called with `bash ~/bin/scriptname`
set -e # bail out early if any command fails
set -u # fail if we hit unset variables
set -o pipefail # fail if any component of any pipe fails

# Usually our workspace is in ~/workspace -- but not on
# all on-call machines.
: "${WORKSPACE:="$HOME/workspace"}"
# this is equivalent to:
# WORKSPACE="${WORKSPACE:-"$HOME/workspace"}"
# which means the user can override the WORKSPACE variable, but if they don't,
# it'll be set to $HOME/workspace by default
#
# To understad how it works, type:
#   `help :`
#   `info "(bash.info)Shell Parameter Expansion"`

# set env var DEBUG to 1 to enable debugging
[[ -z "${DEBUG:-""}" ]] || set -x

bold=$(tput bold)
normal=$(tput sgr0)

# print out usage when something goes wrong
usage() {
  echo "usage: $0 blabla"
}


main() {
    service_name_to_delete=$1; shift

    if [[ "${service_name_to_delete}X" == "X" ]] 
    then
        echo "USAGE: ./bin/delete.sh p-redis"
        exit 1
    fi
    
    check_dependancies

    # Need to log actions to a log file.

    # Output every action to a csv file including what was done, org, space app etc.

    recreation_commands=()
    service_instances=$(cf curl /v2/service_instances | jq -r -c .resources[])

    for service_instance in ${service_instances} 
    do
        plan_url=$(echo ${service_instance} | jq -r .entity.service_plan_url)
        service_instance_name=$(echo ${service_instance} | jq -r .entity.name)
    if [[ "${plan_url}X" != "X" ]] 
    then
        plan_name=$(cf curl ${plan_url} | jq -r .entity.name)
        service_url=$(cf curl ${plan_url} | jq -r .entity.service_url)
        service_name=$(cf curl ${service_url} | jq -r .entity.label)

        # Issue when p.redis is depoyed - need to check code to why an issue
        if [[ "${service_name_to_delete}" == ${service_name} ]]
        then
            match "Found service instance using ${bold}"${service_name}/${plan_name}"${normal}"

            ## Unbind service
            service_bindings_url=$(echo ${service_instance} | jq -r .entity.service_bindings_url)
            binding_resources=$(cf curl ${service_bindings_url} | jq -r -c .resources[])
            for binding_resource in ${binding_resources} 
            do
                binding_guid=$(echo ${binding_resource} | jq -r .metadata.guid)
                app_url=$(echo ${binding_resource} | jq -r .entity.app_url)
                app_name=$(cf curl ${app_url} | jq -r .entity.name)
                app_guid=$(cf curl ${app_url} | jq -r .metadata.guid)
                app_space_url=$(cf curl ${app_url} | jq -r .entity.space_url)
                space_name=$(cf curl ${app_space_url} | jq -r .entity.name)
                org_url=$(cf curl ${app_space_url} | jq -r .entity.organization_url)
                org_name=$(cf curl ${org_url} | jq -r .entity.name)
                
                info "Unbinding app ${bold}${app_name}${normal} from service ${bold}${service_instance_name}${normal} in ${bold}${org_name}/${space_name}${normal}"


                ## Loop to check what service and then call required backup function
                backup_service ${service_name_to_delete} ${org_name} ${space_name} ${service_instance_name}

                ## Maybe stop the apps that are bound to the service??

                recreation_commands+=("cf target -o ${org_name} -s ${space_name}; cf cs ${service_name} ${plan_name} ${service_instance_name}")
                recreation_commands+=("cf target -o ${org_name} -s ${space_name}; cf bs ${app_name} ${service_instance_name}; cf restart ${app_name}")

                ## unbind services
                # echo "DELETE /v2/apps/$app_guid/service_bindings/$binding_guid"
                #cf curl -X DELETE "/v2/apps/$app_guid/service_bindings/$binding_guid" && echo "Unbound; needs restarting." || echo "Failed to unbind for some reason."
                success "Binding unmapped ${bold}${app_name}${normal} from service ${bold}${service_instance_name}${normal} in ${bold}${org_name}/${space_name}${normal}"
            done

        ## Restage App
        app_restage ${app_name}

        ## Delete Service  
        info "Deleting service instance ${bold}${service_instance_name}${normal} in ${bold}${org_name}/${space_name}${normal}"
        service_instance_url=$(echo ${service_instance} | jq -r .metadata.url)
        info "DELETE ${bold}${service_instance_url}${normal}"
        ## Temp disabled action
        #cf curl -X DELETE $service_instance_url && echo "Deleted." || echo "Failed to delete for some reason."
        success "Deleted ${bold}${service_instance_url}${normal}"
        else
            info "Skipping service instance ${bold}$service_instance_name${normal} for service ${bold}"${service_name}/${plan_name}"${normal}"
        fi
    else
        error "Skipping as parsing broken: ${bold}${service_instance}${normal}"
    fi
    echo
    done

    ## Delete tile

    ## Readd tile

    ## Apply Tile configuration

    ## Apply changes

    ## Recreate services & Rebind
    # Need to save to a file
    echo Recreate service instances and bindings:
    # if [ "${recreation_commands[@]}" -eq 0 ] 
    # then
    #     echo "No commands to recreate"
    # else
        for command in "${recreation_commands[@]}" 
        do
            echo $command
        done
    # fi
}

## Restage App

## Restore App data

############
## Functions

backup_service() {
    # backup up service

    local service=$1;
    local org=$2;
    local space=$3;
    local servie_name=$4;

    dest="/tmp/mysql_${org}_${space}_${service_name}"

    if [[ "${service}" == "p-mysql" ]]
    then
        # do mysql backup
        info "Backing up MySQL service called ${servie_name}"
        cf mysqldump mysql --single-transaction > ${dest}.sql 2> /dev/null
        success "Extracted to ${dest}.sql"

        recreation_commands+=("cat ${dest}.sql | cf mysql ${servie_name}")

        # To restore "cat database-dump.sql | cf mysql my-db"
    elif [[ "${service}" == "p-redis" ]]
    then
        info "Backing up Redis service called ${servie_name}"
    elif [[ "${service}" == "p-rabbitmq" ]]
    then
        info "Backing up Redis service called ${servie_name}"
    else
        error "No backup option for service $1"
        # Backup Rabbit
    fi
}

# mysql_backup() {
#     #cf mysqldump test-db --single-transaction > development_projectA_test-db.sql
# }


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



check_dependancies() {
    if [[ "$(which jq)X" == "X" ]] 
    then
        echo "Please install jq"
        exit 1
    fi
    if [[ "$(which cf)X" == "X" ]] 
    then
        echo "Please install cf"
        exit 1
    fi

    # Check mysql installed & PATH exported
    # Check mysql cf plugin is install - cf install-plugin -r "CF-Community" mysql-plugin
}



app_restage() {
    info "Restaging app $1"
    #cf restage ${1} >/dev/null && success "$1 restaged" || error "Failed to restage for some reason."
    #success "$1 restaged"
}

main "$@"