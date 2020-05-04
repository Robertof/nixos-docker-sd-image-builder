#!/bin/sh
set -eu

if [ -n "${QEMU_CLEANUP+x}" ]; then
  echo "waiting until build is finished to clean QEMU up..."
  nc -v -l -p 11111
fi

echo "clearing previous QEMU binfmt setups..."
mount -t binfmt_misc binfmt_misc /proc/sys/fs/binfmt_misc/

for i in /proc/sys/fs/binfmt_misc/qemu*; do
  if [ -e "$i" ]; then
    echo " removing $i..."
    echo -1 > $i
  else
    echo " nothing to do"
  fi
done
