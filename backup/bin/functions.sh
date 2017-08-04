#!/bin/bash

##
## utility functions
##

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
    printf "\r\033[2K [ \033[00;32mOK\033[0m ] $1\n"
}

error() {
    (>&2 echo "$(date) - ERROR - $@")
}

panic() {
    error $@
    exit 1
}

##
## shell 'alias' functions
##

#
# makes uaac available either, by using the regular command
# or in an OpsMan environment using 'bundle exec'
#
uaac() {
	cmd=$(which uaac)
	if [ "$?" -ne "0" ]; then
		# check if we are OpsMan Bundle related
		if [ -f "/home/tempest-web/tempest/web/vendor/uaac/Gemfile" ]; then
			export BUNDLE_GEMFILE=/home/tempest-web/tempest/web/vendor/uaac/Gemfile
			bundle exec uaac "$@"
			export BUNDLE_GEMFILE=
		else
			panic "No bosh binary found"
		fi
	# uaac installed via gem install
	else
		$cmd "$@"
	fi
}

#
# makes bosh available either, by using the regular command
# or in an OpsMan environment using 'bundle exec'
#
bosh() {
	cmd=$(which bosh)
	if [ "$?" -ne "0" ]; then
		# check if we are OpsMan Bundle related
		if [ -f "/home/tempest-web/tempest/web/vendor/bosh/Gemfile" ]; then
			export BUNDLE_GEMFILE=/home/tempest-web/tempest/web/vendor/bosh/Gemfile
			bundle exec bosh "$@"
			export BUNDLE_GEMFILE=
		else
			panic "No uaac binary found"
		fi
	else
		# bosh installed via gem install
		$cmd "$@"
	fi
}

#
# Alias for an authenticated curl. Adds a Authorization Header
# to each call, as well as ignores SSL issues.
# 
# depends on: $UAA_TOKEN
# 
acurl() {
	curl -k -H "Authorization: Bearer ${UAA_TOKEN}" "$@"
}

#
# Alias for an authenticated curl that only return the HTTP CODE.
# Adds a Authorization Header to each call, as well as ignores SSL issues.
#
# depends on: $UAA_TOKEN
#
acurl_response_code() {
	acurl -s -o /dev/null -w "%{http_code}" "$@"
}

##
## UAA specific
##

#
# authenticate with the help of 'uaac' and 'return'
# the current token
#
# arg1: client_id
# arg2: client_secret
#
uaa_authenticate() {
	uaac token client get $1 -s $2 > /dev/null
	uaac context | grep access_token | awk '{print $2}'
}

##
## OpsMan specific
##

#
# When other users are logged into OpsMan, OpsMan API returns
# for most calls a '409 - Conflict'. By checking for a 409 we 
# determine if all sessions must be closed
#
# arg1: OM_HOST
#
om_logout_others() {
	#OM_HOST=$1
	http_code=$(acurl_response_code https://${OM_HOST}/api/v0/uaa/tokens_expiration)
	if [ "$http_code" -eq "409" ]; then
		info "Other users are logged in. Logging them out."
		om_logout # $OM_HOST
	fi
}

#
# Logout all from OpsMan by issueing a "DELETE /api/v0/sessions" command
# 
# arg1: OM_HOST
#
om_logout() {
	#OM_HOST=$1
	http_code=$(acurl_response_code https://${OM_HOST}/api/v0/sessions -X DELETE)
	if [ "$http_code" -eq "200" ]; then
		success "Logged out users."
	else
		error "Couldn't log out users. Response: ${http_code}"
	fi
}

#
#
# arg1: file_to_check (can also be a dir)
# arg2: threshold in bytes
#
dir_size_greater_than_threshold() {
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

# delete child directories in provided directory that are CREATED before retention period
#  arg1: dir to check
#  arg2: retention = older than (possible value e.g. '1d', '1w' etc.)
cleanup_backup() {
	retention=$1
	dir_to_check=$2

	find $dir_to_check -type d -mtime +$retention -delete
	return $?
}


#
# Alias for an authenticated OM. Adds a Authorization details
# to each call, as well as ignores SSL issues.
# 
aom() {
    om --skip-ssl-validation --target ${CFOPS_HOST} --username ${OPSMAN_USERNAME} --password ${OPSMAN_PASSWORD} "$@"
}

#
# Alias for an BBR deployment backups including the auth params
# 
bbr_ert() {
    BOSH_CLIENT_SECRET=${BOSH_CLIENT_SECRET} \
    bbr deployment \
    --target ${BOSH_ADDRESS} \
    --username ${BOSH_CLIENT} \
    --deployment ${ERT_DEPLOYMENT_NAME} \
    --ca-cert ${BOSH_CA_CERT_PATH} \
    "$@"
}

#
# Alias for an BBR deployment backups including the auth params
# 
bbr_director() {
    bbr director \
    --host "${BOSH_ADDRESS}" \
    --username bbr \
    --private-key-path <(echo "${BBR_PRIVATE_KEY}") \
    "$@"
}