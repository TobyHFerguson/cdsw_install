#!/bin/sh -x
exec >~/jdk_security.log 2>&1
yum -y install unzip
curl -O -j -k -L -H 'Cookie: oraclelicense=accept-securebackup-cookie' http://download.oracle.com/otn-pub/java/jce/7/UnlimitedJCEPolicyJDK7.zip
unzip -o -j -d /usr/java/jdk1.7.0_67-cloudera/jre/lib/security UnlimitedJCEPolicyJDK7.zip
