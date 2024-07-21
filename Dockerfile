FROM ghcr.io/pr0ton11/ceph-cft:main as cft
FROM alpine:latest

RUN apk add --no-cache ca-certificates grep curl uuidgen ceph18 ceph18-radosgw ceph18-mgr-dashboard

LABEL org.opencontainers.image.title=ceph-yocto
LABEL org.opencontainers.image.description="A minimal development environment for Ceph"
LABEL org.opencontainers.image.version=v1.0.0
LABEL org.opencontainers.image.licenses=Apache-2.0
LABEL org.opencontainers.image.url=https://github.com/pr0ton11/ceph-yocto
LABEL org.opencontainers.image.source=https://github.com/pr0ton11/ceph-yocto
LABEL org.opencontainers.image.authors=pr0ton11

# Install ceph-cft
COPY --from=cft --chown=root:root /app/ceph-cft /usr/local/bin/ceph-cft
RUN chmod +x /usr/local/bin/ceph-cft

# Timezone
ENV TZ=Etc/UTC

# Ceph configuration
ENV RGW_ID "1"
ENV RGW_ZONE_GROUP default
ENV RGW_ZONE default
ENV RGW_DOMAIN s3.localhost

# Secrets (Change these to your own)
ENV ACCESS_KEY yoctodefault
ENV SECRET_KEY yoctodefault
ENV DASHBOARD_USERNAME yoctoadmin
ENV DASHBOARD_PASSWORD yoctoadmin

# Ports
EXPOSE 7480
EXPOSE 8080

# Add default configuration
COPY ./ceph.conf /etc/ceph/ceph.conf

COPY ./entrypoint.sh /entrypoint.sh
ENTRYPOINT /entrypoint.sh
