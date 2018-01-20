#!/bin/bash -x

exec >~/kerberos_client.log 2>&1

yum -y install krb5-workstation openldap-clients unzip

echo Adding supergroup and cdsw user

groupadd supergroup
useradd -G supergroup -u 12354 hdfs_super
useradd -G supergroup -u 12345 cdsw
echo Cloudera1 | passwd --stdin cdsw


