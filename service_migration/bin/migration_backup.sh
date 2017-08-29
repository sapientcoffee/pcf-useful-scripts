#!/usr/bin/env bash

set -e # bail out early if any command fails
set -u # fail if we hit unset variables
set -o pipefail # fail if any component of any pipe fails

# Usually our workspace is in ~/workspace -- but not on machines.
: "${WORKSPACE:="$HOME/workspace"}"
script_dir=$(dirname $0)

# Credentials File
source $script_dir/../config/creds.conf

touch ${WORKING_DIR}/migration_backup.log
exec 3>&1 1>>${WORKING_DIR}/migration_backup.log 2>&1
# echo "This is stdout"
# echo "This is stderr" 1>&2
# echo "This is the console (fd 3)" 1>&3
# echo "This is both the log and the console" | tee /dev/fd/3


# exec 3>&1 4>&2
# trap 'exec 2>&4 1>&3' 0 1 2 3
# exec 1>${WORKING_DIR}/migration_backup.log 2>&1


# set env var DEBUG to 1 to enable debugging
[[ -z "${DEBUG:-""}" ]] || set -x

bold=$(tput bold)
normal=$(tput sgr0)

main() {
    # Ensure tile name is passed as part of the command execution
    service_name_to_delete=$1; shift
    if [[ "${service_name_to_delete}X" == "X" ]] 
    then
        panic "USAGE: migration_backup.sh p-redis"
        #exit 1
    fi
    
    # Check all the tools are avilable to run script
    check_dependancies

    recreation_commands=()
    mapping_csv=(org,space,service,service_name,app)
    service_instances=$(cf curl /v2/service_instances | jq -r -c .resources[])

    # Backup Redis if thats being migrated
    if [[ "${service_name_to_delete}" == "p-redis" ]]
    then
        info "Backing up Redis"
        backup_service ${service_name_to_delete}
        success "Redis Backed up"
    fi

    # Work out bindings for apps/services and unbind/delete services
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

                # Unbind each app from the service
                service_bindings_url=$(echo ${service_instance} | jq -r .entity.service_bindings_url)
                binding_resources=$(cf curl ${service_bindings_url} | jq -r -c .resources[])
                for binding_resource in ${binding_resources} 
                do
                    # Collect details required for doing the work
                    binding_guid=$(echo ${binding_resource} | jq -r .metadata.guid)
                    app_url=$(echo ${binding_resource} | jq -r .entity.app_url)
                    app_name=$(cf curl ${app_url} | jq -r .entity.name)
                    app_guid=$(cf curl ${app_url} | jq -r .metadata.guid)
                    app_space_url=$(cf curl ${app_url} | jq -r .entity.space_url)
                    space_name=$(cf curl ${app_space_url} | jq -r .entity.name)
                    org_url=$(cf curl ${app_space_url} | jq -r .entity.organization_url)
                    org_name=$(cf curl ${org_url} | jq -r .entity.name)
                    
                    info "Unbinding app ${bold}${app_name}${normal} from service ${bold}${service_instance_name}${normal} in ${bold}${org_name}/${space_name}${normal}"

                    # Backup the service data
                    if [[ "${service_name_to_delete}" == "p-mysql" ]]
                    then 
                        info "Backing up service called ${service_name_to_delete}"
                        restore=$(backup_service ${service_name_to_delete} ${org_name} ${space_name} ${service_instance_name})
                        success "Backup Complete"
                    fi

                    # Document mappings and also recraetion commands
                    mapping_csv+=(${org_name},${space_name},${service_name},${service_instance_name},${app_name})
                    recreation_commands+=("cf target -o ${org_name} -s ${space_name}; cf cs ${service_name} ${plan_name} ${service_instance_name}")

                    # p-service-register takes a bit of time to start therefore add some logic to delay
                    if [[ "${service_name_to_delete}" == "p-service-registry" ]]
                    then
                        recreation_commands+=(while [[ $(cf service ${service_instance_name} | grep Status)  == *“progress”* ]])
                        recreation_commands+=(do)
                        recreation_commands+=(sleep 5)
                        recreation_commands+=("echo “Registry creation in progress”;")
                        recreation_commands+=(done)
                    fi

                    recreation_commands+=("cf target -o ${org_name} -s ${space_name}; cf bs ${app_name} ${service_instance_name}")

                    # If MySQL uncomment this line
                    if [[ "${service_name_to_delete}" == "p-mysql" ]]
                    then 
                        recreation_commands+=("${restore}")
                    fi
                    
                    
                    recreation_commands+=("cf restage ${app_name}")

                    # Maybe stop the apps that are bound to the service??

                    # Action the unbind
                    # echo "DELETE /v2/apps/$app_guid/service_bindings/$binding_guid"
                    info "cf curl -X DELETE "/v2/apps/$app_guid/service_bindings/$binding_guid""
                    # DISABLED ###cf curl -X DELETE "/v2/apps/$app_guid/service_bindings/$binding_guid" && success  "Unbound" || echo "Failed to unbind for some reason."
                    success "Binding unmapped ${bold}${app_name}${normal} from service ${bold}${service_instance_name}${normal} in ${bold}${org_name}/${space_name}${normal}"

                    # Restage App once the service binding has been removed
                    app_restage ${app_name} ${org_name} ${space_name}
                done

                # Delete Service instance  
                info "Deleting service instance ${bold}${service_instance_name}${normal} in ${bold}${org_name}/${space_name}${normal}"
                service_instance_url=$(echo ${service_instance} | jq -r .metadata.url)
                info "DELETE ${bold}${service_instance_url}${normal}"
                info "cf curl -X DELETE $service_instance_url"
                # DISABLED ###cf curl -X DELETE $service_instance_url && echo "Deleted." || echo "Failed to delete for some reason."
                success "Deleted ${bold}${service_instance_url}${normal}"
        
        else
            info "Skipping service instance ${bold}$service_instance_name${normal} for service ${bold}"${service_name}/${plan_name}"${normal}"
        fi
    else
        error "Skipping as parsing broken: ${bold}${service_instance}${normal}"
    fi
    echo
    done

    # Output the mappings to a csv
    info "Service mappings for ${service_name} - ${WORKING_DIR}/${service_name_to_delete}_service_mappings.csv;"
    echo
    for csv in "${mapping_csv[@]}" 
    do
        echo $csv | tee -a ${WORKING_DIR}/${service_name_to_delete}_service_mappings.csv | tee /dev/fd/3
    done

    echo
    for command in "${recreation_commands[@]}" 
    do
        echo $command | tee -a ${WORKING_DIR}/${service_name_to_delete}_restore_cmds.txt | tee /dev/fd/3
    done
    
}


############
## Functions
############

backup_service() {
    # local service=${1};
    # local org=${2};
    # local space=${3};
    # local servie_name=${4};

    if [[ "${1}" == "p-mysql" ]]
    then

        # will need to connect to space and org 1st 
        if [ ! -d ${WORKING_DIR}/mysql ]; then
            mkdir -p ${WORKING_DIR}/mysql;
        fi
        dest="${WORKING_DIR}/mysql/p-mysql-${2}-${3}-${4}.sql"
       # cf target -o ${2} -s ${3}; cf mysqldump ${4} --single-transaction > ${dest} 2> /dev/null
       ## DISABLED ###cf target -o ${2} -s ${3}; cf mysqldump ${4} --single-transaction --skip-add-locks > ${dest} 2> /dev/null

        # Check dump file size not 0
        dir_size_greater_than_threshold ${dest} 0
        ret=$?
        [[ "$ret" == 0 ]] || panic "Backup failed. MySQL dump seems to be empty for ${4}"

        # Copy the export and remove `LOCK TABLES line` the --skip-add-locks flag removes the need for this
        #sed -Ei.orig '/^(UN)?LOCK TABLES/ d' ${dest}

        # Create Restore Commnad - To restore "cat database-dump.sql | cf mysql my-db"
        local restore_cmd
        restore_cmd="cf target -o ${2} -s ${3}; cat ${dest}.sql | cf mysql ${4}"
        echo ${restore_cmd}    
        #return "${restore_cmd}";

    elif [[ "${1}" == "p-redis" ]]
    then
       info "Backing up Redis service called"
        
        # deployments=$(bosh -e gcp deployments --json | jq -r -c '.Tables[].Rows[].name')
        # for deployment in ${deployments} 
        # do
        #     if [[ "${deployment}" =~ ^p-redis ]]
        #     then
        #         info "Backing up p-redis deployment called ${deployment}"
        #         bosh -e gcp -d ${deployment} ssh cf-redis-broker -c 'sudo -i /var/vcap/jobs/service-backup/bin/manual-backup'
        #         #bosh -e gcp -d  ${deployment} ssh dedicated-node -c 'sudo -i tar -zcvf /var/vcap/store/redis/redis_node_backup.tgz /var/vcap/store/redis'
        #         #bosh -e gcp -d  ${deployment} ssh dedicated-node -c 'sudo -i hostname'
        #         #bosh -e gcp -d p-redis-5f4ad9e4435bed1dec77 scp dedicated-node:/var/vcap/store/redis/redis_node_backup.tgz ~/backup/redis/redis_node_backup.tgz
        #     fi
        # done
                # bosh -e gcp deployments --json
                # bosh -e gcp -d p-mysql-419df594448c3df19a4e instances
                # bosh -e gcp -d p-redis-5f4ad9e4435bed1dec77 ssh cf-redis-broker -c 'sudo -i /var/vcap/jobs/service-backup/bin/manual-backup'
                # bosh -e gcp -d p-redis-5f4ad9e4435bed1dec77 ssh dedicated-node -c 'sudo -i tar -zcvf /var/vcap/store/redis/redis_node_backup.tgz /var/vcap/store/redis'
                # in the dest work out the mapping name for the backup file
                # bosh -e gcp -d p-redis-5f4ad9e4435bed1dec77 scp dedicated-node:/var/vcap/store/redis/redis_node_backup.tgz ~/backup/redis/redis_node_backup.tgz

    # elif [[ "${1}" == "p-rabbitmq" ]]
    # then
    #     #info "Backing up RabbitMQ service called ${servie_name}"
    #     # rabbitmqadmin export rabbit-backup.config (http://<URL>:15672/cli)
    #     success "NO BACKUP setup for p-rabbitmq" 
    else
        error "No backup option for service ${1}"
    fi
}

log_date() {
    return $(date "+%Y%m%d %H%M%S")
}

info() {
    #echo "$(date) - INFO  - $@"
	printf " [ \033[00;34m..\033[0m ] $(date) - INFO - $@\n" | tee /dev/fd/3
}

debug() {
	#echo "$(date) - DEBUG  - $@"
	printf "\r [ \033[0;33m?\033[0m ]$(date) - DEBUG - $@\n " | tee /dev/fd/3
}

success () {
    printf "\r\033[2K [ \033[00;32mOK\033[0m ] $(date) - SUCCESS - $1\n" | tee /dev/fd/3
}

match () {
    printf "\r\033[2K[ \033[00;32mMATCH\033[0m ] $1\n" | tee /dev/fd/3
}

error() {
    (>&2 echo "$(date) - ERROR - $@") | tee /dev/fd/3
}

panic() {
    error $@
    exit 1
}

check_dependancies() {
    if [[ "$(which jq)X" == "X" ]] 
    then
        echo "Please install jq" | tee /dev/fd/3
        exit 1
    fi
    if [[ "$(which cf)X" == "X" ]] 
    then
        echo "Please install cf" | tee /dev/fd/3
        exit 1
    fi

    # Check mysql installed & PATH exported
    # Check mysql cf plugin is install - cf install-plugin -r "CF-Community" mysql-plugin
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
			echo "File '$path_of_file' is smaller than defined threshold of '$threshold'" | tee /dev/fd/3
			files_lower_exist=1
		fi
	done

	if [ "$files_lower_exist" -eq 1 ]; then
		return 2
	fi

	return 0
}

app_restage() {
    info "Restaging app $1"
    info "cf target -o ${2} -s ${3}; cf restage ${1} >/dev/null && success "$1 restaged" || error "Failed to restage for some reason.""
 # DISABLED   ###
 cf target -o ${2} -s ${3}; cf restage ${1} >/dev/null && success "$1 restaged" || error "Failed to restage for some reason."
    success "$1 restaged"
}

main "$@"