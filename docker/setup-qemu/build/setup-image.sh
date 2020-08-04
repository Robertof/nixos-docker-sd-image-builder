#!/bin/sh
set -eu

if [ -z "${QEMU_PKG_URL+x}" ] || [ -z "${QEMU_PKG_HASH+x}" ]; then
    echo "determining version of QEMU to use..."
    readonly DEBIAN_PKG_WEB_PAGE="https://packages.debian.org/unstable/amd64/qemu-user-static/download"
    curl -o /tmp/deb_pkg_page "https://packages.debian.org/unstable/amd64/qemu-user-static/download"
    if ! QEMU_PKG_URL="$(grep -Eo "https?://ftp.debian.org.*_amd64\.deb" /tmp/deb_pkg_page)"; then
        echo "unable to retrieve QEMU version from $DEBIAN_PKG_WEB_PAGE, please raise an issue" 2>&1
        exit 1
    fi
    if ! QEMU_PKG_HASH="$(grep SHA256 /tmp/deb_pkg_page | grep -o '<tt>.*</tt>' | sed 's/[^a-fA-F0-9]//g')"; then
        echo "unable to retrieve QEMU package hash from $DEBIAN_PKG_WEB_PAGE, please raise an issue" 2>&1
        exit 1
    fi
    echo "QEMU package URL: $QEMU_PKG_URL"
    echo "QEMU package hash: $QEMU_PKG_HASH"
    rm /tmp/deb_pkg_page
fi

wget "$QEMU_PKG_URL"

QEMU_PKG=qemu*.deb

echo "verifying hash of" $QEMU_PKG "..."
# note: spaces matter here!
echo "$QEMU_PKG_HASH " $QEMU_PKG > sha256

sha256sum -c sha256 || exit 1

echo "extracting..."
# avoid extracting the whole thing (which is pretty big uncompressed), only retrieve the AArch64
# binary.
dpkg --fsys-tarfile $QEMU_PKG | tar xvF - ./usr/bin/qemu-aarch64-static --strip=3

echo "image is ready"
