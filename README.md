# cdsw_install
Automated installed of CDH 5.12, CDSW 1.1 with Director 2.5

Basic idea is to have a single definition of a cluster which is shared across multiple cloud providers and to make it very simple for a user to say 'I want this cluster to be on cloud provider X, or cloud provider Y', confident that the cluster definition is the same; i.e. to separate out the cluster configuration that is independent of cloud providers from that which is unique to each provider and to make it easy for the user to indicate which cloud provider to use. 

We support and test on two cloud providers (AWS and GCP), and the user choose which cloud provider to use by choosing the top level or provider conf file (`aws.conf` or `gcp.conf`).

## File Organization
### Overview
The system comprises a set of files, some common across cloud providers, and some specific to a particular cloud provider. The common files (and those which indicate which cloud provider to user) are all in the top level directory; the cloud provider specific files are cloud provider specific directories.
### File Kinds
There are three kinds of files:
+ Property Files - You are expected to modify these. They match the `*.properties` shell pattern and use the (Java Properties format)[https://docs.oracle.com/javase/8/docs/api/java/util/Properties.html#load-java.io.Reader-]
+ Conf files - You are not expected to modify these. They match the `*.conf` shell pattern and use the (HOCON format)[https://github.com/typesafehub/config/blob/master/HOCON.md) format (a superset of JSON).
+ SECRET files - these have the prefix `SECRET` and are used to hold secrets for each provider. The exact format is provider specific.

The intent is that those items that you need to edit are in format (`*.properties` files) that is easy to edit, whereas those items that you don't need to touch are in the harder to edit HOCON format (i.e. `*.conf` files).

### Directory Structure
The top level directory contains the main `conf` files (`aws.conf` & `gcp.conf`). These are the files that indicate which cloud provider is to be used.

The `aws` and `gcp` directories contain the files relevant to each cloud provider. We'll reference the general notion of a provider directory using the `$PROVIDER` nomenclature, where `$PROVIDER` takes the value `aws` or `gcp`.

The main configuration file is `$PROVIDER.conf`. This file itself includes the files needed for the specific cloud provider. We will only describe the properties files here:

* `$PROVIDER/provider.properties` - a file containing the provider configuration for Amazon Web Services
* `$PROVIDER/ssh.properties` - a file containing the details required to configure passwordless ssh access into the machines that director will create.
* `$PROVIDER/owner_tag.properties` - a file containing the mandatory value for the `owner` tag which is used to tag all VM instances. Within the Cloudera FCE account a VM without an owner tag will be deleted. It is customary (but not enforced) to use your Cloudera id for this tag value.
* `$PROVIDER/kerberos.properties` - an *optional* file containing the details of the Kerberos Key Distribution Center (KDC) to be used for kerberos authentication. (See Kerberos Tricks below for details on how to easily setup an MIT KDC and use it). *If* `kerberos.properties` is provided then a secure cluster is set up. If `kerberos.properties` is not provided then an insecure cluster will be setup.

For GCP you will need to ensure that the plugin supports rhel7. Do this by adding the following line to your `google.conf` file. This file should be located in the provider directory: `/var/lib/cloudera-director-plugins/google-provider-*/etc` (where the `*` matches the version - something like `1.0.4` - of your plugins). You will likely have to create your own copy of google.conf by copying `google.conf.example` located in the same directory. Note that the exact path to the relevant image is obtained by navigating to GCP's 'Images' section and finding the corresponding OS/URL pair.
```
     rhel7 = "https://www.googleapis.com/compute/v1/projects/rhel-cloud/global/images/rhel-7-v20171025"
```

Assuming gloud is on your path, then this script will do exactly what you need:
```
sudo tee /var/lib/cloudera-director-plugins/google-provider-*/etc/google.conf 1>/dev/null <<EOF
google {
  compute {
    imageAliases {
      centos6="$(gcloud compute images list  --filter='name ~ centos-6-v.*' --uri)",
      centos7="$(gcloud compute images list  --filter='name ~ centos-7-v.*' --uri)",
      rhel6="$(gcloud compute images list  --filter='name ~ rhel-6-v.*' --uri)",
      rhel7="$(gcloud compute images list  --filter='name ~ rhel-7-v.*' --uri)"
    }
  }
}
EOF 

## SECRET files
SECRET files are ignored by GIT and you must construct them yourself. We recommend setting their mode to 600, although that is not enforced anywhere.
## AWS
The secret file for AWS is  `aws/SECRET.properties`. It is in Java Properties format and contains the AWS secret access key:
```
AWS_SECRET_ACCESS_KEY=
```
Mine, with dots hiding characters from the secret key, looks like:
```
AWS_SECRET_ACCESS_KEY=53Hrd................r0wiBbKn3
```
If you fail to set up  the `AWS_SECRET_KEY` then you'll find that cloudera-director silently fails, but grepping for AWS_SECRET_KEY in the local log file will reveal all:

```sh
[centos@ip-10-0-0-239 ~]$ unset AWS_ACCESS_KEY_ID #just to make sure its undefined!
[centos@ip-10-0-0-239 ~]$ cloudera-director bootstrap-remote filetest.conf --lp.remote.username=admin --lp.remote.password=admin
Process logs can be found at /home/centos/.cloudera-director/logs/application.log
Plugins will be loaded from /var/lib/cloudera-director-plugins
Java HotSpot(TM) 64-Bit Server VM warning: ignoring option MaxPermSize=256M; support was removed in 8.0
Cloudera Director 2.4.0 initializing ...
[centos@ip-10-0-0-239 ~]$ 
```
Looks like its failed, right, because it doesn't continue on. No error message! But if you execute:
```
[centos@ip-10-0-0-239 ~]$ grep AWS_SECRET ~/.cloudera-director/logs/application.log
com.typesafe.config.ConfigException$UnresolvedSubstitution: filetest.conf: 28: Could not resolve substitution to a value: ${AWS_SECRET_ACCESS_KEY}
```
You'll discover the problem! (Or there's another problem, and you should look in that log file for details).

### GCP
The secret file for GCP is called `SECRET.json`. It contains the full Google Secret Key, in JSON format, that you obtained when you made your google account.

Mine, with characters of the private key id and lines of the private key replaced by dots, looks like:
```
{
  "type": "service_account",
  "project_id": "gcp-se",
  "private_key_id": "b27f..................66fea",
  "private_key": "-----BEGIN PRIVATE KEY-----\nMIIEvgIBADANBgkqhkiG9w0BAQEFAASCBKgwggSkAgEAAoIBAQDMUKtOk000wkvJ\np/ZdwfkbpowUGMqpn2a0oQ9eTwIaLnPvrTIP3JcibWU7xkzoPXlD4hiANlkSqDqy
.
.
.
.
.
.
UC2sMUZ1rtLCv14qg4iiXuA/RExTs1zRaZZ0r4c\nTDiZwBJEbs0flCAziv7mJ4TZ3LfGKCtrTOhUWRw/jfDHP+uJOpH2isGmytZ7uWVN\ndfllnxLITzHEQEMh0rbc/g3n\n-----END PRIVATE KEY-----\n",
  "client_email": "tobys-service-account@gcp-se.iam.gserviceaccount.com",
  "client_id": "108988546221753267035",
  "auth_uri": "https://accounts.google.com/o/oauth2/auth",
  "token_uri": "https://accounts.google.com/o/oauth2/token",
  "auth_provider_x509_cert_url": "https://www.googleapis.com/oauth2/v1/certs",
  "client_x509_cert_url": "https://www.googleapis.com/robot/v1/metadata/x509/tobys-service-account%40gcp-se.iam.gserviceaccount.com"
}
```

# Workflow
## Pre-requisites
+ Ensure that Director server is setup correctly
+ If using Kerberos check that you can construct a client and get a ticket from it.

## Preparation
+ Choose the cloud provider you're going to work with and edit the `$PROVIDER/*.properties` and `$PROVIDER/SECRET` files appropriately.
+ Ensure that all the files (including the SSH key file) is available to director (i.e copy or clone as necessary to the director server machine).
+ Ensure that the `$PROVIDER/kerberos.properties` file is either absent (you don't want a kerberized cluster) or is present and correct (you want Director to kerberize your cluster using the given parameters)

## Cluster Creation
+ Execute a director bootstrap command using the cloud provider you chose:
```sh
cloudera-director bootstrap-remote $PROVIDER.conf --lp.remote.username=admin --lp.remote.password=admin
```

## Post Creation
+ Once completed, use your cloud provider's console to find the public IP (`CDSW_PIB`) address of the CDSW instance. Its name in the cloud provider's console will begin with `cdsw-`. 
+ You can reach the CDSW at `cdsw.CDSW_PIB.nip.io`. See below for details.

All nodes in the cluster will contain the user `cdsw`. That user's password is `Cloudera1`. (If you used my mit kdc installation scripts from below then you'll also find that this user's kerberos username and password are `cdsw` and `Cloudera1` also).

## Troubleshooting
There are two logs of interest:
* client log: $HOME/.cloudera-director/logs/application.log on client machine
* server log: /var/log/cloudera-director-server/application.log on server machine

If the cloudera-director client fails before communicating with the server you should look in the client log. Otherwise look in the server log.

The server log can be large - I truncate it frequently; especially before using a new conf file!
### GCP
#### No Plugin
If the client fails with this message:
```sh
* ErrorInfo{code=PROVIDER_EXCEPTION, properties={message=Mapping for image alias 'rhel7' not found.}, causes=[]}
```
then you've not configured the plugin for GCP, as detailed in the above section.
#### Old Plugin
If the client fails thus:
```
* Requesting an instance for Cloudera Manager ............ done
* Installing screen package (1/1) .... done
* Suspended due to failure ...
```
and the server log contains something like this:
```
peers certificate marked as not trusted by the user
```
then you've got a plugin configured, but its out of date. Go figure out the latest plugin URL and update the GCP plugins.


## Limitations & Issues
Relies on an [nip.io](http://nip.io) trick to make it work.

You'll need to set two YARN config variables by hand 
+ `yarn.nodemanager.resource.memory-mb`
+ `yarn.scheduler.maximum-allocation-mb`
+ 
These are setup in the `common.conf` file, but if there's a problem (the values are inappropriate) then you'll see errors when you run a Spark job from CDSW in the CDSW project's console.

## NIP.io tricks
(NIP.io)[http://nip.io] is a public bind server that uses the FQDN given to return an address. A simple explanation is if you have your kdc at IP address `10.3.4.6`, say, then you can refer to it as `kdc.10.3.4.6.nip.io` and this name will be resolved to `10.3.4.6` (indeed, `foo.10.3.4.6.nip.io` will likewise resolve to the same actual IP address). (Note that earlier releases of this project used `xip.io`, but that's located in Norway and for me in the USA `nip.io`, located in the Eastern US, works better.)

This technique is used in two places:
+ In the director conf file to specify the IP address of the KDC - instead of messing around with bind or `/etc/hosts` in a bootstrap script etc. simply set the KDC_HOST to `kdc.A.B.C.D.xip.io` (choosing appropriate values for A, B, C & D as per your setup)
+ When the cluster is built you will access the CDSW at the public IP address of the CDSW instance. Lets assume that that address is `C.D.S.W` (appropriate, some might say) - then the URL to access that instance would be http://ec2.C.D.S.W.xip.io

This is great for hacking around with ephemeral devices such as VMs and Cloud images!

## Useful Scripts
I use [install_director.sh](https://github.com/TobyHFerguson/director-scripts/blob/master/cloud-lab/scripts/install_director.sh) to install director, and [install_mit_kdc.sh](https://github.com/TobyHFerguson/director-scripts/blob/master/cloud-lab/scripts/install_mit_kdc.sh) to install an mit kdc. (There's also [install_mit_client.sh](https://github.com/TobyHFerguson/director-scripts/blob/master/cloud-lab/scripts/install_mit_client.sh) to create a client for testing purposes.).  
## Kerberos Tricks
(Refer to the mit scripts linked above for details).
## MIT KDC
I setup an MIT KDC in the Director image and then create a `kerberos.conf` to use that:
```
krbAdminUsername: "cm/admin@HADOOPSECURITY.LOCAL"
krbAdminPassword: "Passw0rd!"

# KDC_TYPE is either "Active Directory" or "MIT KDC"
#KDC_TYPE: "Active Directory"
KDC_TYPE: "MIT KDC"

KDC_HOST: "hadoop-ad.hadoopsecurity.local"

# Need to use KDC_HOST_IP if KDC_HOST is not in DNS. Cannot use /etc/hosts because CDSW doesn't read it
# See DSE-1796 for details

KDC_HOST_IP: "10.0.0.82"

SECURITY_REALM: "HADOOPSECURITY.LOCAL"

KRB_MANAGE_KRB5_CONF: true

#KRB_ENC_TYPES: "aes128-cts-hmac-sha1-96 arcfour-hmac-md5"
KRB_ENC_TYPES: "aes256-cts-hmac-sha1-96 aes128-cts-hmac-sha1-96 arcfour-hmac-md5"

# Note use of aes256 - if you find you can get a ticket but not use it then this might be the problem
# You'll need to either remove aes256 or include the jce libraries
```
### Server Config
In `/var/kerberos/krb5kdc/kdc.conf`:
```
[kdcdefaults]
 kdc_ports = 88
 kdc_tcp_ports = 88

[realms]
 HADOOPSECURITY.LOCAL = {
 acl_file = /var/kerberos/krb5kdc/kadm5.acl
 dict_file = /usr/share/dict/words
 admin_keytab = /var/kerberos/krb5kdc/kadm5.keytab
 supported_enctypes = aes256-cts-hmac-sha1-96:normal aes128-cts-hmac-sha1-96:normal arcfour-hmac-md5:normal
 max_renewable_life = 7d
}
```
In `/var/kerberos/krb5kdc/kadm5.acl` I setup any principal with the `/admin` extension as having full rights:

```
*/admin@HADOOPSECURITY.LOCAL	*
```

I then execute the following to setup the users etc:
```sh
sudo kdb5_util create -P Passw0rd!
sudo kadmin.local addprinc -pw Passw0rd! cm/admin
sudo kadmin.local addprinc -pw Cloudera1 cdsw

systemctl start krb5kdc
systemctl enable krb5kdc
systemctl start kadmin
systemctl enable kadmin
```

Note that the CM username and credentials are `cm/admin@HADOOPSECURITY.LOCAL` and `Passw0rd!` respectively.

### Client Config (Managed by Cloudera Manager)
In `/etc/krb5.conf` I have this:
```
[libdefaults]
 default_realm = HADOOPSECURITY.LOCAL
 dns_lookup_realm = false
 dns_lookup_kdc = false
 ticket_lifetime = 24h
 renew_lifetime = 7d
 forwardable = true
 default_tgs_enctypes = aes256-cts-hmac-sha1-96 aes128-cts-hmac-sha1-96 arcfour-hmac-md5
 default_tkt_enctypes = aes256-cts-hmac-sha1-96 aes128-cts-hmac-sha1-96 arcfour-hmac-md5
 permitted_enctypes = aes256-cts-hmac-sha1-96 aes128-cts-hmac-sha1-96 arcfour-hmac-md5

[realms]
 HADOOPSECURITY.LOCAL = {
  kdc = 10.0.0.82
  admin_server = 10.0.0.82
 }
 ```
 (Note that the IP address used is that of the private IP address of the director server; this is stable over reboot
 so works well)
 
## ActiveDirectory
(Deprecated - I found this image to be unstable. It would just stop working after 3 days or so.)
I use a public ActiveDirectory ami setup by Jeff Bean: `ami-a3daa0c6` to create an AD instance. 

The username/password to the image are `Administrator/Passw0rd!`

Allow at least 5, maybe 10 minutes for the image to spin up and work properly. 

The kerberos settings (which you'd put into `kerberos.conf`) are:

```
krbAdminUsername: "cm@HADOOPSECURITY.LOCAL"
krbAdminPassword: "Passw0rd!
KDC_TYPE: "Active Directory"
KDC_HOST: "hadoop-ad.hadoopsecurity.local"
KDC_HOST_IP: # WHATEVER THE INTERNAL IP ADDRESS IS FOR THIS INSTANCE
SECURITY_REALM: "HADOOPSECURITY.LOCAL"
AD_KDC_DOMAIN: "OU=hadoop,DC=hadoopsecurity,DC=local"
KRB_MANAGE_KRB5_CONF: true
KRB_ENC_TYPES: "aes256-cts-hmac-sha1-96 aes128-cts-hmac-sha1-96 arcfour-hmac-md5"
```
(Don't forget to drop the aes256 encryption if your images don't have the Java Crypto Extensions installed)

## Standard users and groups
I use the following to create standard users and groups, running this on each machine in the cluster:
```sh
sudo groupadd supergroup
sudo useradd -G supergroup -u 12354 hdfs_super
sudo useradd -G supergroup -u 12345 cdsw
echo Cloudera1 | sudo passwd --stdin cdsw
```
And then adding the corresponding hdfs directory from a single cluster machine:
```sh
kinit cdsw
hdfs dfs -mkdir /user/cdsw
```
