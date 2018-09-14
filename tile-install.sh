#!/bin/bash
#==============================================================================
# Title:                tile-install.sh
# Description:          This will traverse the local directroy and install each
#                       Pivotal tile to the PCF OpsMgr of your choice.
#                       Its based on the tile having .pivotal extension.
# Author:          		Rob Edwards (@clijockey)
# Date:                 03/02/17
# Version:              0.1
# Notes:                
#                       
# Limitations/issues:
#==============================================================================

# Set some output colours for feedback during setup
info () {
    printf " [ \033[00;34m..\033[0m ] $1\n"
}

user () {
    printf "\r [ \033[0;33m?\033[0m ] $1 "
}

success () {
    printf "\r\033[2K [ \033[00;32mOK\033[0m ] $1\n"
}

fail () {
    printf "\r\033[2K [\033[0;31mFAIL\033[0m] $1 \n"
    echo ''
    exit
}

# Check if OM is present on the system
if type om >/dev/null 2>&1 ; then
    success "Discovered OM command set globally!"
    execution_cmd=om
elif type ./om >/dev/null 2>&1 ; then
    success "Discovered OM command set in local directory!"
    execution_cmd=./om
else 
    fail "Could not detect the OM command set, please obtain from https://github.com/pivotal-cf/om/releases"
fi

# Check if required parameters have been passed, if not prompt user to input or check if 
# global variables exist $OpsMgr-Target, $OpsMgr-user $OpsMgr-pass
if [[ ! -z "${1}" || ! -z "${2}" || ! -z "${3}" ]]; then
    target=$1
    user=$2
    pass=$3
    success "Params being passed from CLI!"
elif [[ ! -z "${OpsMgr_Target}" || ! -z "${OpsMgr_User}" || ! -z "${OpsMgr_Pass}" ]]; then
    target=${OpsMgr_Target}
    user=${OpsMgr_User}
    pass=${OpsMgr_Pass}
    success "Prams located from system variables!"
else
    read -e -p 'Enter Ops Manager target: ' target
    read -e -p 'Enter Ops Manager Username: ' user
    read -s -p 'Enter Password: ' pass
    success "User input of params!"
fi

# print the tiles that will be installed and confirm with a y to proceed
#find . -name '*.pivotal'
printf "\n \tTiles found in the directory; \n"
for f in $(find . -name '*.pivotal'); do 
    printf "\t $f\n"
    done
printf "\n"

#read -r -p "Do you want to proceed and install the listed tiles? (y/n) " response
user "Do you want to proceed and install the listed tiles? (y/n) "
read -e response

# If user responds with y proceed to upload each tile
if [[ "$response" =~ ^([yY][eE][sS]|[yY])+$ ]]; then
    for f in $(find . -name '*.pivotal'); do 
        if $execution_cmd -k -t https://$target -u $user -p $pass upload-product -p $f; then
            success "Install tile $f "
        else
            fail "Install tile $f"
        fi
    done
else
    fail "User cancelled script!!"
fi

# Finish
success "Completed Script"
echo ''
