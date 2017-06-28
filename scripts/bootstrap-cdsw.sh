#!/bin/bash -x

exec >~/bootstrap-cdsw.log 2>&1

cd /etc/yum.repos.d
curl -O https://archive.cloudera.com/cdsw/1/redhat/7/x86_64/cdsw/cloudera-cdsw.repo
rpm --import https://archive.cloudera.com/cdsw/1/redhat/7/x86_64/cdsw/RPM-GPG-KEY-cloudera
yum -y install cloudera-data-science-workbench
