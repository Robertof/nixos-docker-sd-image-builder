FROM alpine:latest

ARG QEMU_PKG_URL
ARG QEMU_PKG_HASH
ARG QEMU_SCRIPT_REPO_REVISION

WORKDIR /root
COPY *.sh /root/
RUN apk add dpkg
RUN sh /root/setup-image.sh

CMD ["/bin/sh", "/root/run.sh"]
