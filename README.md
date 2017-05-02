# cdsw_install
Automated installed of CDSW with Director 2.4

This repo contains Director 2.4 configuration files that can be used to install a cluster to demonstrate CDSW.

The main configuration file is `aws.conf`. This file itself refers to other files:
* `aws_provider.conf` - a file containing the provider configuration for Amazon Web Services
* `ssh.conf` - a file containing the details required to configure passwordless ssh access into the machines that director will create.
* `kerberos.conf` - an optional file containing the details of an ActiveDirectory system to be used for kerberos authentication.

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

## XIP.io tricks
(XIP.io)[http://xip.io] is a public bind server that uses the FQDN given to return an address. A simple explanation is if you have your kdc at IP address `10.3.4.6`, say, then you can refer to it as `kdc.10.3.4.6.xip.io` and this name will be resolved to `10.3.4.6` (indeed, `foo.10.3.4.6.xip.io` will likewise resolve to the same actual IP address).

This technique is used in two places:
+ In the director conf file to specify the IP address of the KDC - instead of messing around with bind or `/etc/hosts` in a bootstrap script etc. simply set the KDC_HOST to `kdc.A.B.C.D.xip.io` (choosing appropriate values for A, B, C & D as per your setup)
+ When the cluster is built you will access the CDSW at the public IP address of the CDSW instance. Lets assume that that address is `C.D.S.W` (appropriate, some might say) - then the URL to access that instance would be http://ec2.C.D.S.W.xip.io

This is great for hacking around with ephemeral devices such as VMs and Cloud images!
