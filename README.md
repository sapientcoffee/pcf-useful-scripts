# Useful Scripts

A collection of scripts that I have used or find useful when working with Pivotal Cloud FOundry (PCF).


## tile-install
The `tile-install.sh` script is intended to hekp with the import of tiles into Ops Manger.

### Usage

You will need to know the FQDN/IP of your Ops manager (target), the user name and password you need to access it. I provided three options to pass this information;

* `./tile-install <target> <user> <password>`
* Using environment variables `$OpsMgr_Target`, `$OpsMgr_User` and `$OpsMgr_Pass`
* Follow the prompts on the screen (example below uses this method)

I uploaded two tiles (`cf-1.9.5` and `p-mysql-1.8.2`) to a directory on my Ops Manager (`~/tiles`) server along with the `tile-install.sh` script from [here](https://github.com/clijockey/pcf-useful-scripts/blob/master/tile-install.sh).

```
.
├── cf-1.9.5-build.3.pivotal
├── om-linux
├── p-mysql-1.8.2.pivotal
├── README.md
└── tile-install.sh

0 directories, 5 files
```

The Ops Manager UI at this point doesn't have any additional tiles available (ERT and MySQL in my example here).

![Ops Manager](https://res.cloudinary.com/dalqykxs4/image/upload/v1486242631/opsMgr_gm5olt.png)

I then executed the script;

```language-bash
redwards@om-pcf-1b:~/tiles$ ./tile-install.sh
 [ OK ] Discovered OM command set in local directory!
Enter Ops Manager target: opsmgr.gcp.#######.com
Enter Ops Manager Username: admin
 [ OK ] User input of params!

 	Tiles found in the directory;
	 ./p-mysql-1.8.2.pivotal
	 ./cf-1.9.5-build.3.pivotal

 [ ? ] Do you want to proceed and install the listed tiles? (y/n)  y
processing product
beginning product upload to Ops Manager
 1.02 GB / 1.02 GB [===================================================================================] 100.00% 18s
2m27s elapsed, waiting for response from Ops Manager...
finished upload
 [ OK ] Install tile ./p-mysql-1.8.2.pivotal
processing product
beginning product upload to Ops Manager
 4.96 GB / 4.96 GB [=================================================================================] 100.00% 2m33s
8m15s elapsed, waiting for response from Ops Manager...
finished upload
 [ OK ] Install tile ./cf-1.9.5-build.3.pivotal
 [ OK ] Completed Script
```

![Imported Tiles](https://res.cloudinary.com/dalqykxs4/image/upload/v1486242632/OpsMgr_with_imported_tiles_ohh9c9.png)

