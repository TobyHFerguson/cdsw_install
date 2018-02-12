#!/bin/sh -x
trap exit ERR
exec >~/users.log 2>&1
echo Adding supergroup and cdsw user

groupadd supergroup
useradd -G supergroup -u 12354 hdfs_super
useradd -G supergroup -u 12345 cdsw
echo Cloudera1 | passwd --stdin cdsw
