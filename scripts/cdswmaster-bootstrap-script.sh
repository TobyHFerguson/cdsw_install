#!/bin/sh
trap exit ERR
exec >~/cdswmaster-bootstrap-script.log 2>&1

# Install jdk 1.8 required by Spark2
#sudo yum remove -y *openjdk*
#rpm -ivh "https://archive.cloudera.com/director/redhat/7/x86_64/director/2.6.0/RPMS/x86_64/oracle-j2sdk1.8-1.8.0+update121-1.x86_64.rpm"

# Mount one volume for application data
device="/dev/xvdh"
mount="/var/lib/cdsw"

echo "Making file system"
sudo mkfs.ext4 -F -E lazy_itable_init=1 "$device" -m 0

echo "Mounting $device on $mount"
if [ ! -e "$mount" ]; then
     sudo mkdir -p "$mount"
fi

sudo mount -o defaults,noatime "$device" "$mount"
echo "$device $mount ext4 defaults,noatime 0 0" >> /etc/fstab

exit 0
