#!/bin/sh -x
exec >~/instancePostCreateScripts.log 2>&1
echo Starting instancePostCreateScript

if rpm -q cloudera-data-science-workbench 
then
echo "This is the CDSW node"

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

DOM="cdsw.$(get_public_ip).nip.io"
MASTER=$(get_local_ip)

sed -i -e "s/\(DOMAIN=\).*/\1${DOM:?}/" /etc/cdsw/config/cdsw.conf
sed -i -e "s/\(MASTER_IP=\).*/\1${MASTER:?}/"  /etc/cdsw/config/cdsw.conf

fi
exit 0
