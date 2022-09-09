#!/usr/bin/env sh

cd "$(dirname "$0")"

echo "Cleaning up containers..."
./run.sh down --rmi all -v

echo "Cleaning any leftover 'binfmt_misc' entry if needed..."

[ "$(uname)" = "Linux" ] && QEMU_CLEANUP=1 sh ./docker/setup-qemu/scripts/update-binfmt.sh

echo "All done! Note that any built image has not been removed, and will be in this directory as '*.img'."
