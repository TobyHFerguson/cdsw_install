# cdsw_install
Automated installed of CDSW with Director 2.4

This repo contains Director 2.4 configuration files that can be used to install a cluster to demonstrate CDSW on
different cloud providers. We support AWS and GCP today.

The basic idea is that you are working with a single instance of Director. You'll use the files contained here to create clusters in either AWS or GCP, by choosing the top level conf file (`aws.conf` or `gcp.conf`).

## File Organization
### File Kinds
There are three kinds of files:
+ Property Files - You are expected to modify these. They match the `*.properties` shell pattern and use the (Java Properties format)[https://docs.oracle.com/javase/8/docs/api/java/util/Properties.html#load-java.io.Reader-]
+ Conf files - You are not expected to modify these. They match the `*.conf` shell pattern and use the (HOCON format)[https://github.com/typesafehub/config/blob/master/HOCON.md) format (a superset of JSON).
+ SECRET files - these have the prefix `SECRET` and are used to hold secrets for each provider. The exact format is provider specific.

Basically the (sometimes complex) structured files are all in HOCON format, and have `.conf` suffix, whereas the easier ones to edit(because they only carry key value pairs) are the `.properties` files.

### Directory Structure
The top level directory contains the main `conf` files (`aws.conf` & `gcp.conf`). We'll refer to them singly or together as `TOP.conf`, depending on context.

The `aws` and `gcp` directories contain the files relevant to each cloud provider. We'll reference the general notion of a provider directory using the `CLOUD` nomenclature.

The main configuration file is `TOP.conf`. This file itself includes the files needed for the specific cloud provider. We will only describe the properties files here:

* `CLOUD/provider.properties` - a file containing the provider configuration for Amazon Web Services
* `CLOUD/ssh.properties` - a file containing the details required to configure passwordless ssh access into the machines that director will create.
* `CLOUD/owner_tag.properties` - a file containing the mandatory value for the `owner` tag which is used to tag all VM instances. Within the Cloudera FCE account a VM without an owner tag will be deleted. It is customary (but not enforced) to use your Cloudera id for this tag value.
* `CLOUD/kerberos.properties` - an *optional* file containing the details of Kerberos Key Distribution Center (KDC) to be used for kerberos authentication. (See Kerberos Tricks below for details on how to easily setup an MIT KDC and use it). If this is provided then a secure cluster is set up. If `kerberos.properties` is not provided then an insecure cluster will be setup.

## SECRET files
SECRET files are ignored by GIT and you must construct them yourself. We recommend setting their mode to 600, although that is not enforced anywhere.
## AWS
The secret file for AWS is called `SECRET.properties`. It is in Java Properties format and contains the AWS secret access key:
```
AWS_SECRET_ACCESS_KEY=
```
If you fail to set up  the `AWS_SECRET_KEY` then you'll find that cloudera-director silently fails, but grepping for AWS_SECRET_KEY in the local log file will reveal all:

```sh
[centos@ip-10-0-0-239 ~]$ unset AWS_ACCESS_KEY_ID #just to make sure its undefined!
[centos@ip-10-0-0-239 ~]$ cloudera-director bootstrap-remote filetest.conf --lp.remote.username=admin --lp.remote.password=admin
Process logs can be found at /home/centos/.cloudera-director/logs/application.log
Plugins will be loaded from /var/lib/cloudera-director-plugins
Java HotSpot(TM) 64-Bit Server VM warning: ignoring option MaxPermSize=256M; support was removed in 8.0
Cloudera Director 2.4.0 initializing ...
[centos@ip-10-0-0-239 ~]$ grep AWS_SECRET ~/.cloudera-director/logs/application.log
com.typesafe.config.ConfigException$UnresolvedSubstitution: filetest.conf: 28: Could not resolve substitution to a value: ${AWS_SECRET_ACCESS_KEY}
```
### GCP
The secret file for GCP is called `SECRET.json`. It contains the full Google Secret Key, in JSON format, that you obtained when you made your google account.

# Workflow
+ Ensure that Director and the optional KDC is setup correctly
+ Choose the cloud provider you're going to work with and edit the properties and SECRET files appropriately.
+ Ensure that all the files (including the SSH key file) is available to director.
+ Execute a director bootstrap command
```sh
cloudera-director bootstrap-remote aws.conf --lp.remote.username=admin --lp.remote.password=admin
```
+ Once completed, use your cloud provider's console to find the public IP (`CDSW_PIB`) address of the CDSW instance. Its name will begin with `cdsw`. 
+ You can reach the CDSW at `cdsw.CDSW_PIB.xip.io`. See below for details.

All nodes in the cluster will contain the user `cdsw`. That user's password is `Cloudera1`. (If you used my mit kdc installation scripts from below then you'll also find that this user's kerberos username and password are `cdsw` and `Cloudera1` also).

You will need to fix up two Yarn parameters using CM before the system is ready to run any Spark jobs:

+ `yarn.scheduler.maximum-allocation-mb`
+ `yarn.nodemanager.resource.memory-mb`

(I set them both to 2GiB for the small system (worker c4.xlarge; cdsw: c4.4xlarge) and that seems to work OK.

For the large system (worker: c4.8xlarge; cdsw: r4.16xlarge) I chose:

+ `yarn.scheduler.maximum-allocation-mb: 55174`
+ `yarn.nodemanager.resource.memory-mb: 20606`
+ `yarn.nodemanager.resource.cpu-vcores: 32`

and that worked OK)

## Limitations
Relies on an [xip.io](http://xip.io) trick to make it work.

You'll need to set two YARN config variables by hand (I used a value of 2048 MB and that worked)
+ `yarn.nodemanager.resource.memory-mb`
+ `yarn.scheduler.maximum-allocation-mb`
+ 
If you don't do this then you'll see errors when you run a Spark job from CDSW.

## XIP.io tricks
(XIP.io)[http://xip.io] is a public bind server that uses the FQDN given to return an address. A simple explanation is if you have your kdc at IP address `10.3.4.6`, say, then you can refer to it as `kdc.10.3.4.6.xip.io` and this name will be resolved to `10.3.4.6` (indeed, `foo.10.3.4.6.xip.io` will likewise resolve to the same actual IP address).

This technique is used in two places:
+ In the director conf file to specify the IP address of the KDC - instead of messing around with bind or `/etc/hosts` in a bootstrap script etc. simply set the KDC_HOST to `kdc.A.B.C.D.xip.io` (choosing appropriate values for A, B, C & D as per your setup)
+ When the cluster is built you will access the CDSW at the public IP address of the CDSW instance. Lets assume that that address is `C.D.S.W` (appropriate, some might say) - then the URL to access that instance would be http://ec2.C.D.S.W.xip.io

This is great for hacking around with ephemeral devices such as VMs and Cloud images!

## Kerberos Tricks
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
