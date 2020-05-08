#!/bin/sh
# Connects to the EC2 instance created by Terraform using the generated SSH keypair and downloads
# the built image to the current directory via SCP.
set -efu

readonly SSH_KEY_PATH="$(mktemp)"
trap "rm '$SSH_KEY_PATH'" EXIT

set -x

terraform output ssh_key > "$SSH_KEY_PATH"
chmod 600 "$SSH_KEY_PATH"

scp -oStrictHostKeyChecking=no \
    -oUserKnownHostsFile=/dev/null \
    -i $SSH_KEY_PATH \
    admin@"$(terraform output instance_ip)":*.img \
    .

echo "Image pulled. DO NOT forget to run 'terraform destroy' once you're done!"
