# NixOS AWS-based SD image builder

This allows to build an SD installer of NixOS for AArch64 systems (including Raspberry Pis) using
native AArch64 AWS EC2 spot instances. It should cost no more than a few cents to build a
full-fledged `img` file, and the entire process with Terraform takes less than 10 minutes.

## Quick start

Ensure your [Terraform](https://www.terraform.io/) install is up to date, then just run
(in this directory):

```sh
terraform init
terraform apply
```

This will download all the necessary plugins and it will (hopefully) build an image. By default,
this will run on the `us-east-2` region and it will use `us-east-2a` as the availability zone. To
change this, run Terraform as follows:

```sh
terraform apply -var 'region=us-east-1' -var 'availability_zone=us-east-1a'
```

To download the built image in the current directory using `scp`, run:

```sh
./pull_image.sh
```

To connect to the machine via SSH, run:

```sh
./remote_ssh.sh
```

This will use the ephemeral SSH key generated when applying the spec and connect to the instance.

**Don't forget to destroy the created resources when you are done:**

```sh
terraform destroy
```

## Details

The Terraform specification will:
- create a new ephemeral SSH key (4096-bit RSA)
- add the key to your AWS account
- create a new spot request as follows:
  - latest Debian Buster AMI
  - `a1.2xlarge` instance with a cap of the current on-demand price, which has 8 threads and
    16 GiB of RAM
  - 16 GiB of EBS storage
- wait until the spot request is fulfilled
- copy the `docker` folder, `sd-card.nix` and `run.sh` to the remote instance
- install the required dependencies and execute `run.sh` remotely.

When running `terraform destroy`, all the resources will be cleared up (including the SSH key).

The SSH key is exported as a (sensitive) output from the Terraform specification, and it's used
along the instance IP in the `pull_image.sh` and `remote_ssh.sh` scripts.

Feel free to customize the `build.tf` file as needed, I have documented it extensively.

Any changes to the configuration or Docker build files can also be done -- Terraform won't clone
another instance of this repo, it will use your local copy.
