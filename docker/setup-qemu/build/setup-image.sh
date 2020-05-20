#!/bin/sh
set -eu

echo "downloading QEMU..."
wget "$QEMU_PKG_URL"

QEMU_PKG=qemu*.rpm

echo "verifying hash of" $QEMU_PKG "..."
# note: spaces matter here!
echo "$QEMU_PKG_HASH " $QEMU_PKG > sha256

sha256sum -c sha256 || exit 1

echo "extracting..."
# avoid extracting the whole thing (which is pretty big uncompressed), only retrieve the AArch64
# binary.
bsdtar xvf $QEMU_PKG --strip-components=3 ./usr/bin/qemu-aarch64-static

echo "image is ready"
