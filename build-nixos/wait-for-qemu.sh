#!/bin/bash
echo "waiting until QEMU container finishes..."

chmod +x aarch64-tester

# this is just a binary which prints "aarch64 runs!". feel free to replace with any other binary
while ! ./aarch64-tester; do
  sleep 1
done

echo "starting build"
