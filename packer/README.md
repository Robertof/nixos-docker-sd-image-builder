# NixOS AWS-based SD image builder

This allows to build an SD installer of NixOS for AArch64 systems (including Raspberry Pis) using
native AArch64 AWS EC2 spot instances. It should cost no more than a few cents to build a
full-fledged `img` file, and the entire process with Packer takes less than 10 minutes.

## Quick start

Ensure your [Packer](https://www.packer.io/) install is up to date, then just run
(in this directory):

```sh
packer build build.pkr.hcl
```

This will set everything up, (hopefully) build an image and download it. If everything worked,
you should see towards the end of your output something like:

```Image successfully built and downloaded as nixos-sd-image-20.03pre-git-aarch64-linux.img```

By default, this will run on the `us-east-1` region and it will use `us-east-1a` as the
availability zone. To change this, run Packer as follows:

```sh
packer build -var 'region=us-east-2' -var 'availability_zone=us-east-2a' build.pkr.hcl
```

## Details

The Packer specification will:
- create a new spot request as follows:
  - latest Debian Buster AMI
  - `a1.2xlarge` instance with a cap of the current on-demand price, which has 8 threads and
    16 GiB of RAM
  - 16 GiB of EBS storage
- wait until the spot request is fulfilled
- copy the `docker` and `config` folders and `run.sh` to the remote instance
- install the required dependencies and execute `run.sh` remotely.

Packer will take care of removing all the used resources when the script ends. To troubleshoot,
pass the `-debug -on-error=ask` flags. See also
[Debugging](https://www.packer.io/docs/other/debugging.html).

Feel free to customize the `build.pkr.hcl` file as needed. It's using the experimental HCL
specification of Packer.

Any changes to the configuration or Docker build files can also be done -- Packer won't clone
another instance of this repo, it will use your local copy.
