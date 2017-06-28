#!/bin/bash -x

exec >~/kerberos_client.log 2>&1

yum -y install krb5-workstation openldap-clients unzip http://archive.cloudera.com/cm5/redhat/7/x86_64/cm/5/RPMS/x86_64/oracle-j2sdk1.7-1.7.0+update67-1.x86_64.rpm
