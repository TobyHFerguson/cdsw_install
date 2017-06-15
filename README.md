# cdsw_install
Automated installed of CDSW with Director 2.4

This repo contains Director 2.4 configuration files that can be used to install a cluster to demonstrate CDSW.

There are two kinds of files:
+ Files you are expected to modify - these match the `*.properties` shell pattern.
+ Files that hold the system structure and which you should leave alone until you know what you're doing - these match the `*.conf` shell pattern

The main configuration file is `aws.conf`. This file itself refers to other files written in [Java Properties format](https://docs.oracle.com/javase/8/docs/api/java/util/Properties.html#load-java.io.Reader-):

* `aws_provider.properties` - a file containing the provider configuration for Amazon Web Services
* `ssh.properties` - a file containing the details required to configure passwordless ssh access into the machines that director will create.
* `owner_tag.properties` - a file containing the mandatory value for the `owner` tag which is used to tag all VM instances. Within the Cloudera FCE account a VM without an owner tag will be deleted. It is customary (but not enforced) to use your Cloudera id for this tag value.
* `kerberos.properties` - an *optional* file containing the details of Kerberos Key Distribution Center (KDC) to be used for kerberos authentication. (See Kerberos Tricks below for details on how to easily setup an MIT KDC and use it). If this is provided then a secure cluster is set up. If `kerberos.properties` is not provided then an insecure cluster will be setup.

To use this set of properties files you need to edit them, and then put them all into the same directory then execute something like:
```sh
AWS_SECRET_KEY=aldsfkja;sldfkj;adkf;adjkf cloudera-director bootstrap-remote aws.conf --lp.remote.username=admin --lp.remote.password=admin
```
replacing the value for the `AWS_SECRET_KEY` variable with the value specific to you and your `AWS_SECRET_KEY_ID` (which is defined in `aws_provider.properties`

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

The CDSW instance you will get will be named after the public ip address of the cdsw instance. The name will be `ec2.PUBLIC_IP.xip.io`. See below for details.

You will have to figure out what this PUBLIC_IP is using your aws console.

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
