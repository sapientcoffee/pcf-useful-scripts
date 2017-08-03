#!/usr/bin/env bash

set -eu

backup_script_dir=$(dirname $0)

# backup configuration
source $backup_script_dir/../config/backup.conf
source $backup_script_dir/functions.sh


# Check OM and BBR are installed


# Get CF deployment guid
info "Obtaining the CF Deployment GUID..."
aom curl -p /api/v0/deployed/products > deployed_products.json
ERT_DEPLOYMENT_NAME=$(jq -r '.[] | select( .type | contains("cf")) | .guid' "deployed_products.json")
success "Obtained the GUID for ERT as ${ERT_DEPLOYMENT_NAME}"

# Retrieve BOSH Director Address and Credentials
# Look at /api/v0/deployed/director/credentials/director_credentials for dir credentials
# Look at /api/v0/deployed/products and api/v0/deployed/products/PRODUCT-GUID/static_ips to get IP
info "Obtain required credentials and certificates.."
aom curl -p /api/v0/deployed/director/manifest > director_manifest.json

BOSH_CLIENT="ops_manager"
BOSH_CLIENT_SECRET=$(jq -r '.jobs[] | select(.name == "bosh") | .properties.uaa.clients.ops_manager.secret' director_manifest.json)
BOSH_ADDRESS=$(jq -r '.jobs[] | select(.name == "bosh") | .properties.director.address' director_manifest.json)
BOSH_CA_CERT_PATH="${PWD}/bosh.crt"
jq -r '.jobs[] | select(.name == "bosh") | .properties.director.config_server.ca_cert' director_manifest.json > "${BOSH_CA_CERT_PATH}"

aom curl -p /api/v0/deployed/director/credentials/bbr_ssh_credentials > bbr_keys.json
BBR_PRIVATE_KEY=$(jq -r '.credential.value.private_key_pem' bbr_keys.json)
BOSH_PRIVATE_KEY=$(jq -r '.credential.value.private_key_pem' bbr_keys.json)
success "Obtained authentication requirements"

# OM to export instalation Settings
# Pivotal recommends that you back up your installation settings by exporting frequently
#aom export-installation --output-file ${OPSMAN_BACKUP}

## Run pre-backup check
info "Checking that backup can run"
bbr_ert pre-backup-check
success "Able to do ERT backup"

## Backup ERT
# Could use the --debug flag
info "Starting ERT backup"
bbr_ert backup --with-manifest
tar -cvf ert-backup.tar cf* --remove-files
success "ERT backed up and placed in archive"

## Backup BOSH Director
info "Starting BOSH backup"
bbr_director backup
tar -cvf p-bosh-backup.tar ${BOSH_ADDRESS}* --remove-files
success "BOSH backed up and placed in archive"

success "Backup Complete"

