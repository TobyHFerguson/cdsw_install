#!/bin/sh -x

trap exit ERR
exec >~/java8-bootstrap-script.log 2>&1
#
# (c) Copyright 2016 Cloudera, Inc.
#
# Licensed under the Apache License, Version 2.0 (the "License");
# you may not use this file except in compliance with the License.
# You may obtain a copy of the License at
#
#   http://www.apache.org/licenses/LICENSE-2.0
#
# Unless required by applicable law or agreed to in writing, software
# distributed under the License is distributed on an "AS IS" BASIS,
# WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
# See the License for the specific language governing permissions and
# limitations under the License.

# We remove any natively installed JDKs, as both Cloudera Manager and Cloudera Director only support Oracle JDKs
sudo yum remove --assumeyes *openjdk* oracle-j2sdk1.7*

# Only install/update java if there isn't a java on the path or if the current version isn't 1.8
which java && java -version 2>&1 | grep -q 1.8.0_121 && { echo "Java 1.8 found. No need to install java"; exit 0; }

echo "Java 1.8 needs to be installed"
sudo rpm -ivh "https://archive.cloudera.com/director/redhat/7/x86_64/director/2.6.0/RPMS/x86_64/oracle-j2sdk1.8-1.8.0+update121-1.x86_64.rpm"

JAVA_HOME=/usr/java/jdk1.8.0_121-cloudera
sudo alternatives --install /usr/bin/java java ${JAVA_HOME:?}/bin/java 10
sudo alternatives --install /usr/bin/javac javac ${JAVA_HOME:?}/bin/javac 10
sudo ln -nfs ${JAVA_HOME:?} /usr/java/latest
sudo ln -nfs /usr/java/latest /usr/java/default


curl -v -j -k -L -O -H "Cookie: oraclelicense=accept-securebackup-cookie" http://download.oracle.com/otn-pub/java/jce/8/jce_policy-8.zip
sudo unzip -o -j -d ${JAVA_HOME:?}/jre/lib/security jce_policy-8.zip

