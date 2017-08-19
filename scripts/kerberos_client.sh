#!/bin/bash -x

exec >~/kerberos_client.log 2>&1

yum -y install krb5-workstation openldap-clients unzip
