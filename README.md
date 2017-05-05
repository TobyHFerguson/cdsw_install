# cdsw_install
Automated installed of CDSW with Director 2.4

This repo contains Director 2.4 configuration files that can be used to install a cluster to demonstrate CDSW.

The main configuration file is `aws.conf`. This file itself refers to other files:
* `aws_provider.conf` - a file containing the provider configuration for Amazon Web Services
* `ssh.conf` - a file containing the details required to configure passwordless ssh access into the machines that director will create.
* `kerberos.conf` - an optional file containing the details of an ActiveDirectory system to be used for kerberos authentication. (See below for details on how to easily setup an AD instance and use it)

To use this set of files you need to edit them, and then put them all into the same directory then execute something like:
```sh
export AWS_SECRET_KEY=aldsfkja;sldfkj;adkf;adjkf
cloudera-director bootstrap-remote aws.conf --lp.remote.username=admin --lp.remote.password=admin
```
Note the use of the AWS_SECRET_KEY envariable. If you fail to set that up then you'll get a validation error.

The CDSW instance you will get will be named after the public ip address of the cdsw instance. The name will be `ec2.PUBLIC_IP.xip.io`. See below for details.

You will need to fix up two Yarn parameters using CM before the system is ready to run any Spark jobs:

+ `yarn.scheduler.maximum-allocation-mb`
+ `yarn.nodemanager.resource.memory-mb`

(I set them both to 2GiB and that seems to work OK.)


## Limitations
Only tested in AWS us-east-1 using the exact network etc. etc. as per the file.

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
I use the following to create standard users and groups:
```sh
sudo groupadd supergroup
sudo useradd -G supergroup -u 12354 hdfs_super
sudo useradd -G supergroup -u 12345 cdsw
echo Cloudera1 | sudo passwd --stdin cdsw
```
