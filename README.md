# cdsw_install
Automated install of Cloudera Data Science Workbench (CDSW) with Director 2.4

This repo contains Director 2.4 configuration files that can be used to install a cluster to demonstrate CDSW.

You will need a working Cloudera Director installation. Instructions on installing Director can be found [here](https://github.com/TobyHFerguson/director-scripts/blob/master/cloud-lab/scripts/install_director.sh).

The main configuration file is `cdsw.conf`. This file itself refers to other files:
* `aws_provider.conf` - a file containing the provider configuration for Amazon Web Services
* `ssh.conf` - a file containing the details required to configure passwordless ssh access into the machines that director will create.
* `kerberos.conf` - an optional file containing the details of an ActiveDirectory system to be used for kerberos authentication. (See Kerberos Tricks below for details on how to easily setup an AD instance and use it)

AMI_ID for us-west-2: ami-71696108
AMI_ID for us-east-1: ami-a5841db3

To use this set of files you need to edit them, and then put them all into the same directory then execute the following commands:
```sh
export AWS_SECRET_KEY=aldsfkja;sldfkj;adkf;adjkf
cloudera-director bootstrap-remote cdsw.conf --lp.remote.username=admin --lp.remote.password=admin
```
Note the use of the AWS_SECRET_KEY envariable. If you fail to set that up then you'll get a validation error.

The CDSW instance you will get will be named after the public ip address of the cdsw instance. The name will be `ec2.PUBLIC_IP.xip.io`. See below for details.

## Pre-Installation Steps
You will need to install a Kerberos KDC on your Cloudera Director node.

A script to automate the installation of MIT Kerberos can be found [here](https://github.com/TobyHFerguson/director-scripts/blob/master/cloud-lab/scripts/install_mit_kdc.sh).

### MIT KDC Setup
If you intend to manually install the MIT KDC, perform the installation steps documented in the script above.

Once the MIT KDC is installed and configured on the Director instance, edit `kerberos.conf` and set the IP address below to the private IP address of your Director instance:
```
krbAdminUsername: "cm/admin@HADOOPSECURITY.LOCAL"
krbAdminPassword: "Passw0rd!"

# KDC_TYPE is either "Active Directory" or "MIT KDC"
#KDC_TYPE: "Active Directory"
KDC_TYPE: "MIT KDC"

KDC_HOST: "hadoop-ad.hadoopsecurity.local"

# Need to use KDC_HOST_IP if KDC_HOST is not in DNS. Cannot use /etc/hosts because CDSW doesn't read it
# See DSE-1796 for details

# The following IP should be set to your Director inatance IP

KDC_HOST_IP: "10.0.0.82"

SECURITY_REALM: "HADOOPSECURITY.LOCAL"

KRB_MANAGE_KRB5_CONF: true

#KRB_ENC_TYPES: "aes128-cts-hmac-sha1-96 arcfour-hmac-md5"
KRB_ENC_TYPES: "aes256-cts-hmac-sha1-96 aes128-cts-hmac-sha1-96 arcfour-hmac-md5"

# Note use of aes256 - if you find you can get a ticket but not use it then this might be the problem
# You'll need to either remove aes256 or include the jce libraries
```
### Server Config
In `/var/kerberos/krb5kdc/kdc.conf` on your Director instance:
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
In `/etc/krb5.conf` on your Director instance:
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

### ActiveDirectory
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


## Post Installation Steps
You will need to fix up two Yarn parameters using CM before the system is ready to run any Spark jobs:

+ `yarn.scheduler.maximum-allocation-mb`
+ `yarn.nodemanager.resource.memory-mb`

(I set them both to 2GiB for the small system (worker c4.xlarge; cdsw: c4.4xlarge) and that seems to work OK.

For the large system (worker: c4.8xlarge; cdsw: r4.16xlarge) I chose:

+ `yarn.scheduler.maximum-allocation-mb: 55174`
+ `yarn.nodemanager.resource.memory-mb: 20606`
+ `yarn.nodemanager.resource.cpu-vcores: 32`

and that worked OK)
### Create Standard users and groups
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


## Limitations
Tested in both AWS us-east-1 and us-west-2.

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
