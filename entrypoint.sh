#!/usr/bin/env ash

# set -eux
# set -o pipefail

ulimit -S 8096

FSID="$(uuidgen)"
MON_HOST="$(hostname -i)"
MON_HOST_SHORT="$(hostname -s)"

echo "ZONE: ${RGW_ZONE}"
echo "ZONE_GROUP: ${RGW_ZONE_GROUP}"
echo "DOMAIN: ${RGW_DOMAIN}"

echo "Template ceph configuration..."
export CEPH_GLOBAL_FSID="${FSID}"
export CEPH_GLOBAL_MON_HOST="${MON_HOST}"

# Configure Ceph based on environment variables
ceph-cft

echo "Create monitor credentials..."
ceph-authtool --create-keyring /tmp/ceph.mon.keyring --gen-key -n mon. --cap mon 'allow *'
ceph-authtool --create-keyring /etc/ceph/ceph.client.admin.keyring --gen-key -n client.admin --cap mon 'allow *' --cap osd 'allow *' --cap mds 'allow *' --cap mgr 'allow *'
ceph-authtool /tmp/ceph.mon.keyring --import-keyring /etc/ceph/ceph.client.admin.keyring

echo "Create initial monitor map..."
monmaptool --create --add "${MON_HOST_SHORT}" "${MON_HOST}" --fsid "${FSID}" --set-min-mon-release reef --enable-all-features --clobber /tmp/monmap
mkdir -p "/var/lib/ceph/mon/ceph-${MON_HOST_SHORT}"
rm -rf "/var/lib/ceph/mon/ceph-${MON_HOST_SHORT}/*"
mkdir /var/run/ceph
chown ceph:ceph /var/run/ceph

echo "Setup Ceph Monitor..."
ceph-mon --mkfs -i "${MON_HOST_SHORT}" --monmap /tmp/monmap --keyring /tmp/ceph.mon.keyring
chown -R ceph:ceph /var/lib/ceph/mon/
ceph-mon --cluster ceph --id "${MON_HOST_SHORT}" --setuser ceph --setgroup ceph

echo "Setup Ceph Manager..."
mkdir -p "/var/lib/ceph/mgr/ceph-${MON_HOST_SHORT}"
ceph auth get-or-create "mgr.${MON_HOST_SHORT}" mon 'allow profile mgr' osd 'allow *' mds 'allow *' > "/var/lib/ceph/mgr/ceph-${MON_HOST_SHORT}/keyring"
chown -R ceph:ceph /var/lib/ceph/mgr/
ceph-mgr --cluster ceph --id "${MON_HOST_SHORT}" --setuser ceph --setgroup ceph

echo "Setup Ceph OSD..."
OSD=$(ceph osd create)
echo "OSD ID: ${OSD}"
mkdir -p "/osd/osd.${OSD}/data"
ceph auth get-or-create "osd.${OSD}" mon 'allow profile osd' mgr 'allow profile osd' osd 'allow *' > "/osd/osd.${OSD}/data/keyring"
ceph-osd -i "${OSD}" --mkfs --osd-data "/osd/osd.${OSD}/data"
chown -R ceph:ceph "/osd/osd.${OSD}/data"
ceph-osd -i "${OSD}" --osd-data "/osd/osd.${OSD}/data" --keyring "/osd/osd.${OSD}/data/keyring"

echo "Setup Ceph RGW..."
mkdir -p "/var/lib/ceph/radosgw/ceph-rgw.${RGW_ID}"
ceph auth get-or-create "client.rgw.${RGW_ID}" osd 'allow rwx' mon 'allow rw' -o "/var/lib/ceph/radosgw/ceph-rgw.${RGW_ID}/keyring"
touch "/var/lib/ceph/radosgw/ceph-rgw.${RGW_ID}/done"
chown -R ceph:ceph /var/lib/ceph/radosgw

ceph config set global rgw_enable_usage_log true
ceph config set global rgw_dns_name "${RGW_DOMAIN}"

echo "Setup RGW Administator..."
radosgw-admin user create --uid=".admin" --display-name="system admin" --system --key-type="s3" --access-key="${ACCESS_KEY}" --secret-key="${SECRET_KEY}"

radosgw --cluster ceph --rgw-zone "${RGW_ZONE}" --name "client.rgw.${RGW_ID}" --setuser ceph --setgroup ceph

echo "Setup Ceph Dashboard..."
ceph mgr module enable dashboard --force
ceph mgr module enable prometheus --force
ceph mgr module enable diskprediction_local --force
ceph mgr module enable stats --force
ceph mgr module disable nfs
ceph config set mgr mgr/dashboard/ssl false --force
ceph dashboard feature disable rbd cephfs nfs iscsi mirroring
echo "${DASHBOARD_PASSWORD}" | ceph dashboard ac-user-create "${DASHBOARD_USERNAME}" -i - administrator --force-password
echo "${ACCESS_KEY}" | ceph dashboard set-rgw-api-access-key -i -
echo "${SECRET_KEY}" | ceph dashboard set-rgw-api-secret-key -i -
ceph dashboard set-rgw-api-ssl-verify False
ceph dashboard motd set info 0 "Running local ceph-yocto container with in memory backend. Do not use in production."

echo "Testing dashboard connectivity"
curl -X 'POST' 'http://127.0.0.1:8080/api/auth' -H 'accept: application/vnd.ceph.api.v1.0+json' -H 'Content-Type: application/json' -d "{ \"username\": \"${DASHBOARD_USERNAME}\", \"password\": \"${DASHBOARD_PASSWORD}\"}"

echo "Ceph is running..."
while ! tail -F /var/log/ceph/ceph* ; do
  sleep 0.1
done

echo "Terminating ceph..."
