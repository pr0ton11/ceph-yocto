#!/usr/bin/env ash

ZONE="$(hostname -s | grep -oP '^[a-z]+[0-9]+')"
ZONE_GROUP="$(hostname -d | grep -oP '^[a-z0-9]+')"
REALM="$(hostname -d | grep -oP '^[a-z0-9]+')"
DOMAIN="$(hostname -d)"
FSID="$(uuidgen)"
MON_HOST="$(hostname -i)"
MON_HOST_SHORT="$(hostname -s)"

echo "ZONE: $ZONE"
echo "ZONE_GROUP: $ZONE_GROUP"
echo "REALM: $REALM"
echo "DOMAIN: $DOMAIN"

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
mkdir -p "/var/lib/ceph/radosgw/ceph-rgw.${MON_HOST_SHORT}"
ceph auth get-or-create "client.rgw.${MON_HOST_SHORT}" osd 'allow rwx' mon 'allow rw' -o "/var/lib/ceph/radosgw/ceph-rgw.${MON_HOST_SHORT}/keyring"
touch "/var/lib/ceph/radosgw/ceph-rgw.${MON_HOST_SHORT}/done"
chown -R ceph:ceph /var/lib/ceph/radosgw
