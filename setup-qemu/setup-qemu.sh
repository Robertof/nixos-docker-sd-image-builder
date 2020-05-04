#!/bin/sh
set -eu

if [ -n "${CLEAR_PREVIOUS_QEMU_BINFMT+x}" ]; then
  sh cleanup-qemu.sh
fi

echo "registering QEMU..."
./binfmt.sh --qemu-path "$(pwd)" --qemu-suffix '-static' --persistent yes

echo "done!"
