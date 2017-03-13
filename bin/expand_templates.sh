[ -f secrets ] || {
cat -  >&2 -<<EOF
No file called "secrets" found'. It must contain this line:

AWS_SECRET_ACCESS_KEY=YOUR KEY VALUE HERE

and you need to replace 'YOUR KEY VALUE HERE' appropriately.

...exiting
EOF
exit 1
}

. envars
. secrets

mkdir -p ./tmp
SSH_PRIVATE_KEY_FILE=./tmp/pk.$$
SED_COMMANDS_FILE=./tmp/cmds.sed.$$
SCRIPTPATH=$( cd $(dirname $0) ; pwd -P )
TEMPLATE_DIR=${SCRIPTPATH:?}/../templates

sed -e 's|\(-----BEGIN RSA PRIVATE KEY-----\)|    privateKey: """\1|' -e 's|\(-----END RSA PRIVATE KEY-----\)|\1"""|' ${SSH_KEYFILE:?} >${SSH_PRIVATE_KEY_FILE:?}

## the sed command file
cat - > ${SED_COMMANDS_FILE:?} <<EOF
s|REPLACE_ME_AMI_ID|${AMI_ID:?}|g
s|REPLACE_ME_AWS_ACCESS_KEY_ID|${AWS_ACCESS_KEY_ID:?}|g
s|REPLACE_ME_AWS_REGION|${AWS_REGION:?}|g
s|REPLACE_ME_AWS_SECRET_ACCESS_KEY|${AWS_SECRET_ACCESS_KEY:?}|g
s|REPLACE_ME_KDC_ENC_TYPES|${KDC_ENC_TYPES:?}|g
s|REPLACE_ME_KDC_HOST|${KDC_HOST:?}|g
s|REPLACE_ME_KDC_SECURITY_REALM|${KDC_SECURITY_REALM:?}|g
s|REPLACE_ME_KDC_TYPE|${KDC_TYPE:?}|g
s|REPLACE_ME_KRB_ADMIN_PASSWORD|${KRB_ADMIN_PASSWORD:?}|g
s|REPLACE_ME_KRB_ADMIN_USERNAME|${KRB_ADMIN_USERNAME:?}|g
s|REPLACE_ME_OWNER|${OWNER:?}|g
s|REPLACE_ME_SECURITY_GROUP_ID|${SECURITY_GROUP_ID:?}|g
s|REPLACE_ME_SUBNET_ID|${SUBNET_ID:?}|g
/REPLACE_ME_SSH_PRIVATE_KEY/{
r ${SSH_PRIVATE_KEY_FILE:?}
d
}
EOF

for t in $(ls ${TEMPLATE_DIR:?}/*.template)
do
    file=$(basename $t .template)
    sed -f ${SED_COMMANDS_FILE} $t >$file
done

    
