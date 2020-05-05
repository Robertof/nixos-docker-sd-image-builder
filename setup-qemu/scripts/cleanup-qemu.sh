#!/bin/sh
set -eu

if [ -z "${QEMU_CLEANUP+x}" ]; then
  echo "warning: cleanup script run without QEMU_CLEANUP flag" >&2
  exit 0
fi

echo "waiting until build is finished to clean QEMU up..."
nc -v -l -p 11111

# will infer what to do reading 'QEMU_CLEANUP'
sh update-binfmt.sh
