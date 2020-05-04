#!/bin/sh
set -eu

echo "downloading qemu..."
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

echo "downloading binfmt script..."
wget -O /tmp/qemu-binfmt-conf.sh "https://git.qemu.org/?p=qemu.git;a=blob_plain;f=scripts/qemu-binfmt-conf.sh;hb=$QEMU_SCRIPT_REPO_REVISION"

echo "patching script to only include aarch64..."
# this monstrosity overrides the default `qemu_target_list` with just `aarch64`. It finds its
# declaration and then waits for an empty line where to inject the overridden target list.
# note: would have done this with Perl, but didn't want to introduce other dependencies
awk '!found && /qemu_target_list/ { found = 1; find_empty = 1 }; find_empty && $0 == "" { print "qemu_target_list=\"aarch64\""; find_empty = 0 }; { print }' /tmp/qemu-binfmt-conf.sh > binfmt.sh
chmod +x binfmt.sh

echo "image is ready"
