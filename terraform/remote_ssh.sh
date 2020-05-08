#!/bin/sh
# Connects to the EC2 instance created by Terraform using the generated SSH keypair.
# Leaves no traces afterwards.
set -efu

readonly SSH_KEY_PATH="$(mktemp)"
trap "rm '$SSH_KEY_PATH'" EXIT

set -x

terraform output ssh_key > "$SSH_KEY_PATH"
chmod 600 "$SSH_KEY_PATH"

ssh -oStrictHostKeyChecking=no \
    -oUserKnownHostsFile=/dev/null \
    -i $SSH_KEY_PATH \
    admin@"$(terraform output instance_ip)"

set +x
echo "DO NOT forget to run 'terraform destroy' once you're done!"
