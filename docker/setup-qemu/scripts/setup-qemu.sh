#!/bin/sh
set -eu

echo "registering QEMU..."
sh update-binfmt.sh qemu-aarch64-static
echo "done!"
