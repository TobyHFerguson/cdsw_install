#!/bin/sh -x
exec >~/instancePostCreateScripts.log 2>&1
echo Starting instancePostCreateScript

function isCDSWMaster() {
    lsblk | grep "cdsw" | wc -l
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

if [ $(isCDSWMaster) -eq 1 ]
then
echo "This is the CDSW master node"

serviceName=$(curl --user $CM_USERNAME:$CM_PASSWORD --request GET http://$DEPLOYMENT_HOST_PORT/api/v18/clusters/$CLUSTER_NAME/services  | grep "CD-CDSW" | grep "name" | cut -d ':' -f 2 | cut -d '"' -f2)

config=$(curl --user $CM_USERNAME:$CM_PASSWORD --request GET http://$DEPLOYMENT_HOST_PORT/api/v18/clusters/$CLUSTER_NAME/services/$serviceName/config)

cdswMasterPublicIp=$(get_public_ip)
newConfig=$(echo $config| sed "s/cdsw.placeholder-domain.com/cdsw.$cdswMasterPublicIp.nip.io/g")

curl --user $CM_USERNAME:$CM_PASSWORD -d "$newConfig" -H "Content-Type: application/json" -X PUT http://$DEPLOYMENT_HOST_PORT/api/v18/clusters/$CLUSTER_NAME/services/$serviceName/config

curl --user $CM_USERNAME:$CM_PASSWORD -d "$serviceName" -X POST http://$DEPLOYMENT_HOST_PORT/api/v18/clusters/$CLUSTER_NAME/services/$serviceName/commands/restart

fi
exit 0
