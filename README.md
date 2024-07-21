# Ceph Yocto

Ceph Yocto is a minimal build container for Ceph RGW (S3) services.

* Built with Alpine Linux, uses packages from the Alpine repositories
* Configurable with environment variables (see configuration reference)
* Does not need any persistent storage, privileged mode, or host network mode


## Configuration Reference

The following environment variables can be used to configure the container itself:

```
# Id of the RGW instance
RGW_ID=1
# Zonegroup to which the RGW instance belongs
RGW_ZONE_GROUP=default
# Zone to which the RGW instance belongs
RGW_ZONE=default
# Domain name of the RGW instance (can be used to access the RGW service with hosts file modification)
RGW_DOMAIN=s3.local
# S3 credentials for the RGW admin user
ACCESS_KEY=yoctodefault
SECRET_KEY=yoctodefault
# Ceph Dashboard credentials
DASHBOARD_USERNAME=yoctoadmin
DASHBOARD_PASSWORD=yoctoadmin
```

Additionally, you can configure the Ceph cluster by utilizing [Ceph-CFT](https://github.com/pr0ton11/ceph-cft)
Example:
```
CEPH_GLOBAL_LOG_FILE='/var/log/ceph/$cluster-$type.$id.log'
CEPH_OSD_OP_QUEUE=wpq
CEPH_MON_LOG_TO_SYSLOG=true
CEPH_TEST_WITHOUT_SECTION=works
CEPH_CONTAINS_WHITESPACES="Hello World"
CEPH_OSD__1_OBJECTER_INFLIGHT_OPS=512
```
