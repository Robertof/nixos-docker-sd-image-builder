# NixOS Docker-based SD image builder
This repository allows you to build a custom SD image of NixOS for your Raspberry Pi (or any other
supported AArch64 device) in about 15-20 minutes on a modern system, without installing any
additional dependencies. 

The default configuration enables OpenSSH out of the box, **allowing to install NixOS on an embedded
device without attaching a display.**

**This works both on `x86_64` systems and native `AArch64` builders**. When needed, QEMU is
used to emulate `AArch64` and [`binfmt_misc`](https://en.wikipedia.org/wiki/Binfmt_misc) is used to
allow transparent execution of AArch64 binaries.

## Quick start
Start by cloning this repo and adding your SSH key(s) in [`sd-card.nix`](sd-card.nix) by replacing
the existing `ssh-ed25519 ...` placeholder. Customize `sd-card.nix` as you like.

Ensure that your [Docker](https://www.docker.com/) is set up and you have a working installation of
[Docker Compose](https://docs.docker.com/compose/), then just run:

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

## Troubleshooting

- If the execution fails due to missing permissions, sorry -- you need to be able to run containers
  with the `--privileged` Docker flag.
- Ensure you have enough memory/swap and disk space. This can require up to 8 GiB of RAM and ~6-7
  GiB of disk space.
- If the build fails with something like:
  ```
  Resizing to minimum allowed size
  resize2fs 1.45.5 (07-Jan-2020)
  Please run 'e2fsck -f temp.img' first.
  ```
  This is a known issue in `nixpkgs` (https://github.com/NixOS/nixpkgs/pull/86366), please edit
  `docker-compose.yml` and uncomment `APPLY_RESIZE2FS_PATCH`. If you want to learn more, I
  [investigated this issue and wrote about
  it](https://rbf.dev/blog/2020/04/why-doesnt-resize2fs-resize-my-fs/).
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
