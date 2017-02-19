# cdsw_install
Automated installed of CDSW with Director 2.3

The config file (`cdsw.conf`) will automatically install a cluster including CDSW. 

# Instructions
+ Modify the `cdsw.conf` file - You need to search for `REPLACE_ME` within the file and make the necessary edits.
+ Use Director 2.3 with the `cdsw.conf` file to create a cluster
+ When complete ssh into the cdsw instance and start up cdsw:
```sh
# cdsw init
....
# watch cdsw status
```
+ Connect to cdsw with the URL as described below under XIP.io tricks


## Limitations
Uses fixed AMI that has AES256 JCE in it.

Only tested in AWS us-east-1 using the exact network etc. etc. as per the file.

Relies on an [xip.io](http://xip.io) trick to make it work.

## XIP.io tricks
(XIP.io)[http://xip.io] is a public bind server that uses the FQDN given to return an address. A simple explanation is if you have your kdc at IP address `10.3.4.6`, say, then you can refer to it as `kdc.10.3.4.6.xip.io` and this name will be resolved to `10.3.4.6` (indeed, `foo.10.3.4.6.xip.io` will likewise resolve to the same actual IP address).

This technique is used in two places:
+ In the director conf file to specify the IP address of the KDC - instead of messing around with bind or `/etc/hosts` in a bootstrap script etc. simply set the KDC_HOST to `kdc.A.B.C.D.xip.oi` (choosing appropriate values for A, B, C & D as per your setup)
+ When the cluster is built you will access the CDSW at the public IP address of the CDSW instance. Lets assume that that address is `C.D.S.W` (appropriate, some might say) - then the URL to access that instance would be http://ec2.C.D.S.W.xip.io

This is great for hacking around with ephemeral devices such as VMs and Cloud images!
