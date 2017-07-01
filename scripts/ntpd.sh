#!/bin/bash -x

exec >~/ntpd.log 2>&1
yum -y install ntp
service ntpd start
chkconfig ntpd on
