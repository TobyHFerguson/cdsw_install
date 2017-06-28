#!/bin/sh -x
exec >~/instancePostCreateScripts.log 2>&1
echo Starting instancePostCreateScript
echo Adding supergroup and cdsw user

groupadd supergroup
useradd -G supergroup -u 12354 hdfs_super
useradd -G supergroup -u 12345 cdsw
echo Cloudera1 | passwd --stdin cdsw

# Check we're on the cdsw node
if rpm -q cloudera-data-science-workbench 
then
echo "This is the CDSW node"

# Install java using alternatives:
alternatives --install /usr/bin/java java /usr/java/jdk1.7.0_67-cloudera/bin/java 2000

# install git
yum -y install git

function googlep() {
	 curl --head --silent http://metadata.google.internal >/dev/null
}

function get_local_ip() {
	 if googlep
	 then
		curl -H "Metadata-Flavor: Google" http://metadata.google.internal/computeMetadata/v1/instance/network-interfaces/0/ip
	else
		curl http://169.254.169.254/latest/meta-data/local-ipv4
	fi
}

function get_public_ip() {
	 if googlep
	 then
		curl -H "Metadata-Flavor: Google" http://metadata.google.internal/computeMetadata/v1/instance/network-interfaces/0/access-configs/0/external-ip
	else
		curl http://169.254.169.254/latest/meta-data/public-ipv4
	fi
}

DOM="cdsw.$(get_public_ip).xip.io"
MASTER=$(get_local_ip)
# Because we only added two disks to the instance then they'll be the
# first and last devices in /etc/fstab. Cut them out and use them for
# the Docker Block Devices (DBD) and teh Abpplication Block Device (ABD)
DBD="$(grep '^/dev' /etc/fstab | cut -f1 -d' ' | head -1)"
ABD="$(grep '^/dev' /etc/fstab | cut -f1 -d' ' | tail -1)"
sed -i -e "s/\(DOMAIN=\).*/\1${DOM:?}/" -e "s/\(MASTER_IP=\).*/\1${MASTER:?}/"  -e "s@\(DOCKER_BLOCK_DEVICES=\).*@\1\"${DBD:?}\"@" -e "s@\(APPLICATION_BLOCK_DEVICE=\).*@\1\"${ABD:?}\"@" /etc/cdsw/config/cdsw.conf
for dev in $(grep '^/dev' /etc/fstab | cut -f1 -d' '); do umount $dev; done
sed -i '/^\/dev/d' /etc/fstab

# Ensure that cdsw can restart after reboot
# Cannot use sysctl directly since the bridge module isn't loaded until after sysctl
# So load the module early and put the configuration so that sysctl can do its stuff
echo bridge > /etc/modules-load.d/bridge.conf
echo "net.bridge.bridge-nf-call-iptables=1" >>/etc/sysctl.d/bridge.conf
# CDSW prereq
# Ensure that the ipv6 networking is NOT disabled - this can be done at boot time:
echo "net.ipv6.conf.all.disable_ipv6=0" >>/etc/sysctl.conf
# Ensure that the hard and soft limits on number of files is set so that cdsw is happy
# First, set the limits permanently:
cat >/etc/security/limits.conf/90-nofile.conf <<EOF
* soft nofile 1048576
* hard nofile 1048576
EOF

# Then, set them in the currently running system:
ulimit -n 1048576

if googlep
then
# Google only offers RHEL7.3, but CDSW checks for RHEL 7.2
# We apply this patch to circumvent the check
(cd /etc/cdsw/scripts
patch <<\EOF
--- -   2017-06-16 20:39:57.318975584 +0000
+++ preinstall-validation.sh    2017-06-16 20:28:50.588007327 +0000
@@ -15,7 +15,7 @@
 
 echo -n "Prechecking OS Version${PAUSE}"
 min_version="7.2" #inclusive
-max_version="7.2.9999" #inclusive
+max_version="7.3.9999"
 lsb_version=$(lsb_release -rs)
 if [ "$?" -ne "0" ]
 then
EOF
)
fi

# CDSW applies a too-strict check for selinux being disabled.
# This requires that the cdsw node be rebooted, so instead we 
# reduce the strength of the check to allow for selinux=permissive

(cd /etc/cdsw/scripts
patch <<\EOF
--- -   2017-06-16 20:39:57.318975584 +0000
+++ preinstall-validation.sh    2017-06-16 20:28:50.588007327 +0000
@@ -74,9 +74,9 @@
 fi
 
 echo -n "Prechecking that SELinux is disabled${PAUSE}"
-grep "^SELINUX=disabled" /etc/selinux/config &> /dev/null
+grep -Ei "^SELINUX=(permissive|disabled)" /etc/selinux/config
 die_on_error $? "Please set SELINUX=disabled in /etc/selinux/config, then reboot"
-getenforce 2>/dev/null | grep 'Disabled' &> /dev/null
+getenforce 2>/dev/null | grep -vi enforc &> /dev/null
 die_on_error $? "Please disable SELinux with setenforce 0"
 echo -e "${OK}"
EOF
)

# init cdsw
# There have been rpcbind service problems preventing cdsw init from working
# and this is an attempt to get around those issues:
systemctl stop rpcbind
systemctl start rpcbind
for i in {1..10}
do
  if cdsw reset && cdsw init
  then
    break
  else
    systemctl restart rpcbind
    sleep 1
  fi
done

## Make sure that we add an auto restart script to the boot sequence
echo "cdsw restart" >> /etc/rc.d/rc.local
chmod a+x /etc/rc.d/rc.local

fi
exit 0
