ARG IMAGE_BASE

FROM ${IMAGE_BASE}alpine:latest

ARG QEMU_PKG_URL
ARG QEMU_PKG_HASH

COPY build/ scripts/ /root/
WORKDIR /root
RUN apk add libarchive-tools
RUN sh /root/setup-image.sh

CMD ["/bin/sh", "/root/run.sh"]
