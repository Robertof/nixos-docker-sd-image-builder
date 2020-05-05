#!/bin/sh
set -eu

# based on `scripts/qemu-binfmt-conf.sh` from QEMU tree
# a big thank you to the author and contributors!
readonly AARCH64_MAGIC='\x7fELF\x02\x01\x01\x00\x00\x00\x00\x00\x00\x00\x00\x00\x02\x00\xb7\x00'
readonly AARCH64_MASK='\xff\xff\xff\xff\xff\xff\xff\x00\xff\xff\xff\xff\xff\xff\xff\xff\xfe\xff\xff\xff'

# detect host arch before proceeding -- this should allow easy support of native aarch64 boxes
case "$(uname -m)" in
arm|armel|armhf|arm64|armv[4-9]*l|aarch64)
  echo "binfmt: detected native ARM build box, skipping binfmt setup!"
  export SKIP_BINFMT=y
  exit 0
  ;;
amd64|i386|i486|i586|i686|i86pc|BePC|x86_64)
  echo "binfmt: detected x86 architecture, proceeding"
  ;;
*)
  echo "binfmt: detected unknown architecture $(uname -m), proceeding anyway -- this will probably fail"
  ;;
esac

# load binfmt_misc
if [ ! -d /proc/sys/fs/binfmt_misc ]; then
  /sbin/modprobe binfmt_misc
fi

# mount if not already done
if [ ! -f /proc/sys/fs/binfmt_misc/register ]; then
  mount -t binfmt_misc binfmt_misc /proc/sys/fs/binfmt_misc
fi

# sanity
if [ ! -w /proc/sys/fs/binfmt_misc/register ]; then
  echo "ERROR: unable to get write access to binfmt_misc -- container must be privileged" >&2
  exit 1
fi

# according to https://www.kernel.org/doc/html/latest/admin-guide/binfmt-misc.html, later entries
# are matched first. thus, we don't need to care about pre-existing entries with the same magic
# as long as we are the ones registering last
readonly INTERPRETER_NAME="qemu-aarch64-docker-nixos" # should be sufficiently unique

# unregister first though if there is already one.
if [ -e /proc/sys/fs/binfmt_misc/$INTERPRETER_NAME ]; then
  echo "binfmt: clearing existing entry for $INTERPRETER_NAME"
  echo -1 > /proc/sys/fs/binfmt_misc/$INTERPRETER_NAME
fi

if [ -n "${QEMU_CLEANUP+x}" ]; then
  echo "binfmt: cleanup done"
  exit 0
fi

readonly QEMU_BINARY="$(readlink -f "$1")"

# time for the magic
# note: flag 'F' (fix-binary) is necessary for this to work properly, as it keeps the binary open
# in the host kernel.
echo ":$INTERPRETER_NAME:M::$AARCH64_MAGIC:$AARCH64_MASK:$QEMU_BINARY:F" > /proc/sys/fs/binfmt_misc/register

echo "binfmt: successfully registered $QEMU_BINARY as an interpreter for aarch64"
