#!/bin/sh -x
exec >~/instancePostCreateScripts.log 2>&1
echo Starting instancePostCreateScript
#echo Adding supergroup and cdsw user

#groupadd supergroup
#useradd -G supergroup -u 12354 hdfs_super
#useradd -G supergroup -u 12345 cdsw
#echo Cloudera1 | passwd --stdin cdsw

# Check we're on the cdsw node
if rpm -q cloudera-data-science-workbench 
then
echo "This is the CDSW node"




# install git
yum -y install git

function get_local_ip() {
    hostname -i
}

function get_public_ip() {
    azure='-H Metadata:true http://169.254.169.254/metadata/instance/network/interface/0/ipv4/ipAddress/0/publicIpAddress?api-version=2017-04-02&format=text'
    google='-H Metadata-Flavor:Google http://metadata.google.internal/computeMetadata/v1/instance/network-interfaces/0/access-configs/0/external-ip'
    aws='http://169.254.169.254/latest/meta-data/public-ipv4'

    for args in "$azure" "$google" "$aws"
    do
	# The sed script scans the curl output. If a 404 Not Found error is found then it quits.
	# Otherwise it prints out the last line (the ip address)
	public_ip=$(curl -i --silent $args | sed -n -e '/^HTTP.*404.*Not.*Found/q' -e '$p')

	[ -n "$public_ip" ] && { break; }
    done
    echo ${public_ip?:"no public ip found for this vm"}
}

function get_disk_name() {
    lsblk --output NAME,MOUNTPOINT --noheadings | grep /data | cut -f1 -d' '
}
DOM="cdsw.$(get_public_ip).nip.io"
MASTER=$(get_local_ip)
# Because we only added two disks to the instance then they'll be the disks
# mounted on the /data drives
# We arbitrarily choose the first disk for the Docker Block Device, and the second
# for the Application Block Device
DBD=/dev/$(get_disk_name | head -1)
ABD=/dev/$(get_disk_name | tail -1)

# If the device names are malformed then exit
[ "$DBD" == "/dev/" ] && { echo "DBD disk not found: DBD=$DBD" 1>&2; exit 1; }
[ "$ABD" == "/dev/" ] && { echo "ABD disk not found: ABD=$ABD" 1>&2; exit 1; }

# Java default used - setup in java8-bootstrap-script.sh
JH=/usr/java/default

sed -i -e "s/\(DOMAIN=\).*/\1${DOM:?}/" /etc/cdsw/config/cdsw.conf
sed -i -e "s/\(MASTER_IP=\).*/\1${MASTER:?}/"  /etc/cdsw/config/cdsw.conf
sed -i -e "s@\(DOCKER_BLOCK_DEVICES=\).*@\1\"${DBD:?}\"@" /etc/cdsw/config/cdsw.conf
sed -i -e "s@\(APPLICATION_BLOCK_DEVICE=\).*@\1\"${ABD:?}\"@" /etc/cdsw/config/cdsw.conf
sed -i -e "s@\(JAVA_HOME=\).*@\1${JH:?}@" /etc/cdsw/config/cdsw.conf

## unmount & delete the /data mountpoints
for mntpoint in $(lsblk --output MOUNTPOINT --noheadings | grep data); do umount $mntpoint; done
sed -i '/\/data.*/d' /etc/fstab


# CDSW prereq
# Ensure that the ipv6 networking is NOT disabled - this can be done at boot time:
echo "net.ipv6.conf.all.disable_ipv6=0" >>/etc/sysctl.conf

sysctl -p

systemctl enable rpcbind
systemctl restart rpcbind
systemctl restart rpc-statd

# Ensure that the hard and soft limits on number of files is set so that cdsw is happy
# First, set the limits permanently:
cat >/etc/security/limits.d/90-nofile.conf <<EOF
* soft nofile 1048576
* hard nofile 1048576
EOF

# Then, set them in the currently running system:
ulimit -n 1048576

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

# Re-enabling iptables. Cloudera Director disables iptables but K8s needs it.
rm -rf /etc/modprobe.d/iptables-blacklist.conf
modprobe iptable_filter

# init cdsw
# There have been rpcbind service problems preventing cdsw init from working
# and this is an attempt to get around those issues:
systemctl stop rpcbind
systemctl start rpcbind
for i in {1..10}
do
  if cdsw reset && echo | cdsw init
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
