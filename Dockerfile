FROM ghcr.io/pr0ton11/radosgw:latest

LABEL org.opencontainers.image.title=ceph-yocto
LABEL org.opencontainers.image.description="A minimal development environment for Ceph"
LABEL org.opencontainers.image.version=0.1.0
LABEL org.opencontainers.image.licenses=Apache-2.0
LABEL org.opencontainers.image.url=https://github.com/pr0ton11/ceph-yocto
LABEL org.opencontainers.image.source=https://github.com/pr0ton11/ceph-yocto
LABEL org.opencontainers.image.authors=pr0ton11


EXPOSE 7480

COPY ./entrypoint.sh /entrypoint
ENTRYPOINT /entrypoint
