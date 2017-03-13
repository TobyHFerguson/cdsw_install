# cdsw_install
Automated installed of CDSW with Director 2.3

This repo will create a Cloudera Director conf file (`aws.conf`) in the current directory that can be used to construct a
CDSW cluster.

It uses templating (as opposed to HOCON substitution variables) because of the need to replace variables in the base `aws.conf`
file in multi-line strings (something that the HOCON format can't do).

## Details
### Overview
This repo contains scripts (in `bin`) and templates (in `templates`) which will create expanded files using the variables defined in `envars` and `secrets`.

In particular it will create `aws.conf

### Instructions
Modify the envars file with the relevant values (I'm assuming you're familiar with Director and AWS!)

Note that the `SSH_KEYFILE` argument is assumed to be the full path to a private key file.

Construct a file `secrets` with a line like this in it, replacing `KEY_YOU_WANT_TO_KEEP_SECRET` with your `AWS_SECRET_ACCESS_KEY` value:
```
AWS_SECRET_ACCESS_KEY=KEY_YOU_WANT_TO_KEEP SECRET
```

(this file is ignored by git, so helps prevent you checking in secrets into your git repo)

Then run `bin/expand_templates.sh` and it will expand out all the files from the `templates` directory that end with `.template` into equivalent files in the current director, replacing envars as they go, and putting in a 'special value' for the SSH keyfile (ugh - I hate special cases!), 

Then use the `aws.conf` file created to make your CDSW installation

### Git
The `secrets` file is ignored by Git, so you can put your AWS_SECRET_KEY in there and not get caught out by inadvertently committing your secrets into a public git repository (which will cause Amazon to send you a bunch of emails and invalidate that key!)

### Testing
The testing directory contains a simple set of test files that will replace the string `REPLACE_ME_XXXX` with `REPLACE_ME_XXXX_TEST`

## Limitations
Requires a kerberize cluster (not certain this is needed anymore, but `aws.conf.template` currently has kerberos in it.

Uses a fixed AMI that has AES256 JCE in it.

Only tested in AWS us-east-1 using the exact network etc. etc. as per the file.

Relies on an [xip.io](http://xip.io) trick to make it work.

## XIP.io tricks
(XIP.io)[http://xip.io] is a public bind server that uses the FQDN given to return an address. A simple explanation is if you have your kdc at IP address `10.3.4.6`, say, then you can refer to it as `kdc.10.3.4.6.xip.io` and this name will be resolved to `10.3.4.6` (indeed, `foo.10.3.4.6.xip.io` will likewise resolve to the same actual IP address).

This technique is used in two places:
+ In the director conf file to specify the IP address of the KDC - instead of messing around with bind or `/etc/hosts` in a bootstrap script etc. simply set the KDC_HOST to `kdc.A.B.C.D.xip.io` (choosing appropriate values for A, B, C & D as per your setup)
+ When the cluster is built you will access the CDSW at the public IP address of the CDSW instance. Lets assume that that address is `C.D.S.W` (appropriate, some might say) - then the URL to access that instance would be http://ec2.C.D.S.W.xip.io

This is great for hacking around with ephemeral devices such as VMs and Cloud images!
