# Backup

A number of scripts have been created to backup PCF

The structure of the backup directory is as follows however this can be adapted to meet Orange requirements;

```
.
├── README.md
├── bin
│   ├── backup_bbr.sh                 # Backup ERT & Bosh using BBR tool
│   ├── backup_bosh.sh                # Backs up Bosh configuration
│   ├── backup_ert.sh                 # Backs up buildpacks, app droplets, source, and app cache
│   ├── backup_ert_bponly.sh          # Backs up buildpacks only and necessitates re-pushing apps
│   ├── backup_om.sh                  # Backs up Ops Manager
│   ├── download_bosh_certificate.sh  # Download the Bosh root CA to the backup server
│   ├── download_dependencies.sh      # script to download dependencies
│   ├── functions.sh                  # Usuable functions used by the backup scripts
│   ├── logout_all.sh                 # Logout all users from OpsMan
│   ├── cfops                         # Backup utility
│   └── restore_om.sh                 # Example retore script if not using the GUI
└── config
    ├── backup.conf.example           # Parameters and credential required by the backup (rename to `backup.conf`)
    └── cron.example
```

The backups are currently run on the Ops Manager instance, this should be moved to another instance, say the jumpbox. The jumpbox was not used due to missing software components and the challenge of downloading them via the locked down proxy.

They are not scheduled and need to be run manually. The location of the scripts on the OpsMan instance is `/home/ubuntu/backup` and the actual backups taken so are `/home/ubuntu/backup/backups/`.

The reason for having a `backup_ert.sh` and `backup_ert_bponly.sh` is because the Cloud Controller does not allow writes while a backup of Elastic Runtime is being taken. This is to ensure that the system is in a consistent state while being backed up. If you are using the internal NFS server as your blobstore, backing it up can take a long time. If leaving the system in a read-only state is a concern, you can opt to only back up the buildpacks and re-push all of your apps (-nfs bp), or you can skip the application cache (-nfs lite) to reduce the time that the Cloud Controller is in a read-only state.

The dependencies to run these scripts are;

* [cfops](http://www.cfops.io/)
* [uaac](https://docs.pivotal.io/pivotalcf/1-10/adminguide/uaa-user-management.html) or [GitHub](https://github.com/cloudfoundry/cf-uaac)
  * This will need the RubyGems site opened up through the proxy (https://rubygems.org/). When I individually downloaded the gems and all their dependencies I got an error messages related to the `ruby-devel` package not being available on the server (the configured repos don't have this package)
* [Bosh](https://bosh.io/docs/bosh-cli.html)
* BBR - this is used for the latest version of PCF (v1.11 +). Can be downloaded from network.pivotal.io


## Configure Backup

* Make sure SSH access via password to OpsMan VM is possible for configured user 
* Configure `config/backup.conf` with properties for you environment
* Download dependencies by running `bin/download_dependencies.sh`
* Create OpsMan (optional) and BOSH (mandatory) client credentials as described below
* Optional: configure cron (see example in `config` directory) and configure `logrotate` (see below)

You will need to populate the `backup.conf` file in the `config/` directory with the required parameters. 

### Create OpsMan Backup Client

**Not needed when using admin user credentials. Please be aware that admin user access via cfops will be deprecated**

```
$ uaac target https://YOUR_OPSMANAGER/uaa
Login as an administrator, and fetch your administrator token
$ # uaac token owner get
Client ID:  opsman
Client secret: (is really empty...)
User name:  admin
Password:  *********

Successfully fetched token via owner password grant.
Target: https://######/uaa
Context: admin, from client opsman


Successfully fetched token via owner passcode grant.
Target: https://YOUR_OPSMANAGER/uaa
Context: admin, from client opsman
On all PCF installations (internal authentication as well as SAML-based authentication), a UAA client with Ops Manager administrative privileges must be created before CF OPS can be used to back up and restore a PCF installation.

# Create a new client
$ uaac client add -i
Client ID:  opsman-backup
New client secret:  DESIRED_PASSWORD
Verify new client secret:  DESIRED_PASSWORD
scope (list):  opsman.admin
authorized grant types (list):  client_credentials
authorities (list):  opsman.admin
access token validity (seconds):  43200
refresh token validity (seconds):  43200
redirect uri (list):
autoapprove (list):
signup redirect url (url):
  scope: opsman.admin
  client_id: NEW_CLIENT_NAME
  resource_ids: none
  authorized_grant_types: client_credentials
  autoapprove:
  access_token_validity: 43200
  refresh_token_validity: 43200
  action: none
  authorities: opsman.admin
  name: NEW_CLIENT_NAME
  signup_redirect_url:
  lastmodified: 1478530665397
  id: NEW_CLIENT_NAME

```

### Create BOSH Director Backup Client

```
uaac target https://BOSH_DIRECTOR_IP:8443 --ca-cert bosh-ca

# use password for 'uaa admin' in OpsMan Credentials tab
$ uaac token owner get
Client ID:  login
Client secret:  ********************************
User name:  admin
Password:  ********************************

Successfully fetched token via owner password grant.
Target: https://#####:8443
Context: admin, from client login


$ uaac client add backup-bosh -i
New client secret:  *********************
Verify new client secret:  *********************
scope (list):
authorized grant types (list):  client_credentials
authorities (list):  bosh.admin
access token validity (seconds):  43200
refresh token validity (seconds):  43200
redirect uri (list):
autoapprove (list):
signup redirect url (url):
  scope: uaa.none
  client_id: backup-bosh
  resource_ids: none
  authorized_grant_types: client_credentials
  autoapprove:
  access_token_validity: 43200
  refresh_token_validity: 43200
  authorities: bosh.admin
  name: backup-bosh
  signup_redirect_url:
  lastmodified: 1488844835600
  id: backup-bosh

```


## MySQL Backup

The backup method for MySQL has not yet been defined. More information on how to back up can be found [here](http://docs.pivotal.io/p-mysql/1-9/backup.html). The options are for the tile to export out the data (for example via SCP) or to do dumps of the database (`mysqldump -u root -p -h MYSQL_SERVER_IP --all-databases > mysql-tile.sql`).


# Restore

To restore you can use the `restore_om.sh` script as an example [here](https://github.com/Pivotal-Field-Engineering/emea-orangegroup/blob/master/scripts/backup/bin/restore_om.sh) 

Alternately you can use the `cfops` restore flag;


```
./cfops restore \
  -opsmanagerhost [Ops Manager VM hostname] \
  -omr [Ops Manager passphrase]
  -clientid [Ops Manager admin client id] \
  -clientsecret [Ops Manager admin client secret] \
  -opsmanageruser ubuntu \
  -destination . \
  -tile ops-manager
```


```
./cfops restore \
  -opsmanagerhost [Ops Manager VM hostname] \
  -clientid [Ops Manager admin client id] \
  -clientsecret [Ops Manager admin client secret] \
  -opsmanageruser ubuntu \
  -destination . \
  -tile elastic-runtime
```

# Tidy UP

Place at the end of the script the follow line to tidy up older files (3 weeks old).

NOTE: place infront of the `exit $ret` line.

```
# delete file older than 3w (full om backup runs only every week)
cleanup_backup 21 $backup_parent_dir
```