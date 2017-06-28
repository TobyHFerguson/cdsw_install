#!/bin/bash -x

exec >~/ntpd.log 2>&1
service ntpd start
chkconfig ntpd on
