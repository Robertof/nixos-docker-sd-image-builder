#!/bin/sh
set -efu

if [ -n "${QEMU_CLEANUP+x}" ]; then
  sh $HOME/cleanup-qemu.sh
else
  sh $HOME/setup-qemu.sh
fi
