# NixOS Docker-based SD image builder
This repository allows you to build a custom SD image of NixOS for your Raspberry Pi (or any other
supported AArch64 device) in about 15-20 minutes on a modern `x86_64` system or about 5 minutes on a
powerful `AArch64` box, without installing any additional dependencies. 

The default configuration enables OpenSSH out of the box, **allowing to install NixOS on an embedded
device without attaching a display.**

**This works both on `x86_64` systems and native `AArch64` builders**. When needed, QEMU is
used to emulate `AArch64` and [`binfmt_misc`](https://en.wikipedia.org/wiki/Binfmt_misc) is used to
allow transparent execution of AArch64 binaries.

A Packer specification is provided in [`packer/`](packer/) which allows to build an
SD image using a native AArch64 instance provided by Amazon EC2. It takes less than 10 minutes!

## Supported devices

Out of the box this supports:

- any device supported by the `sd-image-aarch64` builder of NixOS. This includes the
  **Raspberry Pi 3** and other devices listed [here](https://nixos.wiki/wiki/NixOS_on_ARM).
- **Raspberry Pi 4.**

Any other device can be supported by changing the configuration files in [`config/`](config/).

## Quick start

Start by cloning this repo and opening [`config/sd-image.nix`](config/sd-image.nix) in your favorite
editor. Then:

- choose the target device by following the instructions in the file;
- add your SSH key(s) by replacing the existing `ssh-ed25519 ...` placeholder.

Customize `sd-card.nix` (or add more files) as you like, they will be copied to the container.

_Protip: if you're building for a Raspberry Pi 4 and don't need ZFS, enable
`DISABLE_ZFS_IN_INSTALLER` in [`docker/docker-compose.yml`](docker/docker-compose.yml) to speed
up the build. Please note that if you have already executed `run.sh` once, you need to rebuild
the images after changing this flag using `./run.sh up --build`. Remember to add `patch` to `RUN apk ...` in the `.docker/DockerFile`_

Finally, ensure that your [Docker](https://www.docker.com/) is set up and you have a working
installation of [Docker Compose](https://docs.docker.com/compose/), then just run:

```sh
./run.sh
```

The script is just a wrapper around `docker-compose` which makes sure that the right parameters
are passed to it.

And that's all! Once the execution is done, a `.img` file will be produced and copied in this
directory. To free up the space used by the containers, just run:

```sh
./run.sh down --rmi all -v
```

**WARNING**: This interacts with the host kernel to set up a `binfmt_misc` handler to execute
AArch64 binaries. Due to this, some containers have to be executed with the `--privileged` flag.

## Building on AWS (EC2)

To quickly build an SD image using a native AArch64 EC2 instance, head over to the
[`packer/`](packer/) subdirectory which has a [Packer](https://www.packer.io/)
specification to do it in two commands and less than 10 minutes.

_Before Packer, there was also a Terraform specification, but I removed it in favor of the Packer
one. It is still accessible in the
[`terraform`](https://github.com/Robertof/nixos-docker-sd-image-builder/tree/terraform/terraform)
branch._

## Troubleshooting

- If the execution fails due to missing permissions, sorry -- you need to be able to run containers
  with the `--privileged` Docker flag.
- Ensure you have enough memory/swap and disk space. This can require up to 8 GiB of RAM and ~6-7
  GiB of disk space.
- If the build fails with `cptofs` related errors or something like:
  ```
  Resizing to minimum allowed size
  resize2fs 1.45.5 (07-Jan-2020)
  Please run 'e2fsck -f temp.img' first.
  ```
  This is a known issue (see [[1]](https://github.com/NixOS/nixpkgs/pull/86366) and
  [[2]](https://github.com/NixOS/nixpkgs/pull/82718)). Please edit
  `docker-compose.yml`, uncomment `APPLY_CPTOFS_PATCH` and rerun with `./run.sh up --build`.
  If you want to learn more, I
  [investigated this issue and wrote about it](https://rbf.dev/blog/2020/04/why-doesnt-resize2fs-resize-my-fs/).
- If you are running Docker Toolbox on Windows, you might encounter weird "file not found" errors
  when Nix attempts to find your configuration files. This is due to the fact that Docker Toolbox
  uses VirtualBox to run Docker and `C:\Users` is the only directory shared by default -- thus,
  if you're storing your files in any other path you might run into the issue.
  Follow [the instructions detailed in this great post](https://web.archive.org/web/20200521000637/https://headsigned.com/posts/mounting-docker-volumes-with-docker-toolbox-for-windows/)
  for ways to solve this. Thanks @dsferruzza!
- Failing commands like `bsdtar: Error opening archive: Can't initialize filter; unable to run program "zstd -d -qq"` might be due a preexisting alpine image. Delete it and run the script again.
- For any other problem, open an issue or email me!

## Details

To build an SD image for a foreign architecture, NixOS requires that the host system is able to run
executables for the target architecture. Most people though don't have a powerful ARM64v8 machine at
their disposal to do that, which is the reason why I have made this. Plus, containers reduce the
friction of the entire process to zero. Feel free to check out `docker-compose.yml`, the
documentation should (hopefully) be clear.

Here's how it works in detail:
- When needed, QEMU and [`binfmt_misc`](https://en.wikipedia.org/wiki/Binfmt_misc) are used to
  emulate AArch64 and to allow the host kernel to understand and run AArch64 binaries. To limit the
  risk of security issues, the build process itself runs on an unprivileged container -- the
  containers that deal with QEMU and `binfmt_misc` are separate and do not interact with the build
  process or untrusted binaries.
- When running `docker-compose up`, here's what happens:
  - if emulation is required, the first image to be built is `setup-qemu`, which will:
    - download a pinned version of QEMU from the Debian archives, required for proper emulation. At
      the time of writing, the downloaded version is 5.0.
    - verify the integrity of the downloaded binaries with an hardcoded hash.
    - extract `qemu-aarch64-static` from the package.
  - then, Docker builds `build-nixos`, which will:
    - create an unprivileged user for the NixOS build.
    - download and bootstrap Nix with the default configuration.
    - download the specified version/checkout of `nixpkgs`. By default, this downloads `nixpkgs` for
      the current stable version (20.03).
    - prepare an environment file which adds Nix to `$PATH`, sets `NIX_HOME` and sets a trap which
      notifies the cleanup container using TCP when the build is done.
  - once all the images are built, if emulation is required, `setup-qemu` runs (with privileges),
    and it will:
    - check if a `binfmt_misc` entry which has the same interpreter name exists 
      (`qemu-aarch64-docker-nixos`), removing it if so
    - register `qemu-aarch64-bin` as a `binfmt_misc` handler for AArch64 with the `fix-binary` flag,
      which allows `binfmt_misc` to keep working when the container is destroyed
  - `build-nixos` will be started concurrently (without privileges), and it will:
    - wait until the system is able to understand and execute AArch64 binaries
    - bootstrap the environment
    - build the image
    - copy the image to `/build` as `root` (shared volume)
    - notify `cleanup-qemu` via a simple `nc` call
  - last but not least, if emulation is required, `cleanup-qemu` will also be started concurrently 
    (with privileges), and it will:
    - listen on TCP port `11111` and wait until `build-nixos` connects and unlocks the process
    - after that happens, it will remove `binfmt_misc` handlers that start with `qemu` and leave the
      system clean

## TODO

- [x] Use a unique name as the `binfmt_misc` handler so that it's not needed to nuke the other
  pre-existing QEMU handlers on the system.
- [x] Use a custom script to register QEMU as a `binfmt_misc` handler instead of patching the
  original one.
- [x] Support native `aarch64` compilation
