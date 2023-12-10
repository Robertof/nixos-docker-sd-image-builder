# NixOS Docker-based SD image builder
This repository allows you to build a custom SD image of NixOS for your Raspberry Pi (or any other
supported AArch64 device) in about 15-20 minutes on a modern `x86_64` system or about 5 minutes on a
powerful `AArch64` box, without installing any additional dependencies.

The default configuration enables OpenSSH out of the box, **allowing to install NixOS on an embedded
device without attaching a display.**

**This works both on `x86_64` and `AArch64` (ARM64) systems**. When needed, QEMU is
used to emulate `AArch64` and [`binfmt_misc`](https://en.wikipedia.org/wiki/Binfmt_misc) is used to
allow transparent execution of AArch64 binaries. By default this builds **NixOS 23.11**, though
you can build any other version by amending `NIXPKGS_BRANCH` in
[`docker/docker-compose.yml`](docker/docker-compose.yml).

A Packer specification is provided in [`packer/`](packer/) which allows to build an
SD image using a native AArch64 instance provided by Amazon EC2. It takes less than 10 minutes!

## A note about SSH and headless installation

Since [September 2020](https://github.com/NixOS/nixpkgs/pull/96991) (or NixOS 20.09), OpenSSH is
now enabled by default in pre-built NixOS SD images. However, **NixOS does not ship with a default
password nor keypair for security reasons**, which means you will have to insert an SSH key manually
after you have flashed the image to an SD card. Usually, this is an easier and faster process than
using this repository to build a brand-new NixOS image if you just want to use NixOS headlessly.
This can be done by mounting the SD card block device on a Linux system and adding the key in
`/home/nixos/.ssh/authorized_keys` or `/root/.ssh/authorized_keys` with the appropriate
permissions, or by `chroot`ing and running `passwd`. See
[the official documentation](https://nixos.org/manual/nixos/stable/#sec-installation-booting-networking)
for more information about this process.

This project is still useful in case you want to have further customization capabilities on your
installer image, or in case you want pre-baked images with your SSH key already in them.

## Supported devices

Out of the box this supports any device supported by the `sd-image-aarch64` builder of NixOS.
This includes the **Raspberry Pi 3**, **Raspberry Pi 4** and other devices listed
[here](https://nixos.wiki/wiki/NixOS_on_ARM).

Any other device can be supported by changing the configuration files in [`config/`](config/).

## Getting started

### Cloning

First, clone this repo and move in its directory:
  ```sh
  git clone https://github.com/Robertof/nixos-docker-sd-image-builder && cd nixos-docker-sd-image-builder
  ```

### Configuration

Then, customize [`config/sd-image.nix`](config/sd-image.nix)
(or add more files to the `config` folder) as you like:

1. Choose the target device (default is Raspberry Pi 3):
  ```nix
  imports = [
    ## keep ONLY one of the following uncommented to select target device
    # ./generic-aarch64
    # ./rpi4
    ./rpi3
  ];
  ```
2. Add your SSH key(s) by replacing the existing `ssh-ed25519 ...` placeholder.
  ```nix
  users.extraUsers.nixos.openssh.authorizedKeys.keys = [
    "your-key-goes-here!"
  ];
  ```

<details>
  <summary>If you don't want to setup QEMU and/or `binfmt_misc` on the host system...</summary>
  The run script will automatically detect if you're already running on AArch64 and avoid setting
  up QEMU if that's the case. If you already have a working installation of QEMU with `binfmt_misc`
  set up or want to avoid emulation altogether, then open `run.sh` and remove
  any mention of `WANTS_EMULATION=y`. Note that when emulation is enabled Docker will interact
  with the host kernel to set up a `binfmt_misc` handler to execute AArch64 binaries -- due to
  this, some containers have to be executed with the `--privileged` flag.
</details>

### Building with Docker

Finally, ensure that your [Docker](https://www.docker.com/) is set up and you have a working
installation of [Docker Compose](https://docs.docker.com/compose/), then just run:

```sh
./run.sh
```

The script is just a wrapper around `docker-compose` which makes sure that the right parameters
are passed to it.

Check out the **Troubleshooting** section for common things that might go wrong.

#### Cleanup Docker

And that's all! Once the execution is done, a `.img` file will be produced and copied in this
directory. To free up the space used by the containers, just run:

```sh
./cleanup.sh
```

### Building on AWS (EC2)

To quickly build an SD image using a native AArch64 EC2 instance, head over to the
[`packer/`](packer/) subdirectory which has a [Packer](https://www.packer.io/)
specification to do it in two commands and less than 10 minutes.

_Before Packer, there was also a Terraform specification, but I removed it in favor of the Packer
one. It is still accessible in the
[`terraform`](https://github.com/Robertof/nixos-docker-sd-image-builder/tree/terraform/terraform)
branch._

## Next steps

Once an image is produced by the container it's sufficient to flash it to the SD card of your
choice with any tool which can flash raw images onto block devices. There have been some reports
of issues using Etcher on macOS, thus it might be easier to just use
[`dd`](https://wiki.archlinux.org/index.php/USB_flash_installation_media#Using_dd)
or [`Raspberry Pi Imager`](https://www.raspberrypi.org/blog/raspberry-pi-imager-imaging-utility/)(GUI).

Hopefully, the flashed SD card should _just work_ on your device. Just check your network for the
IP of your Raspberry Pi and connect using SSH and the key you specified:

```sh
ssh -i $PATH_TO_YOUR_KEY nixos@10.0.0.123
```

See the section **Platform-specific steps** for further details about your platform.

### Resources

The
[unofficial wiki](https://nixos.wiki/wiki/NixOS_on_ARM/Raspberry_Pi) contains lots of resources
for possible things you might need or that might go wrong when using NixOS on a Raspberry Pi.
Check out the page for [all ARM devices](https://nixos.wiki/wiki/NixOS_on_ARM) too.

### Platform-specific steps

#### Raspberry Pi 3 and 4

Once your Pi boots and you're logged in, the NixOS installer is ready to use. To proceed with the
_installation_, a system configuration needs to be created:

- The _installer configuration_ (which is the one you edited in the [`config/`](config/) folder) is
  _different_ than the system configuration. The installer configuration is only used to build
  the image -- **using an installer configuration on a production system will not work properly.**
- The _system configuration_ applies to your final working system and will _not_ inherit from the
  previously modified installer configuration. As such, any relevant options (such as users,
  SSH keys, networking etc.) have to be configured again. Please note that once you switch
  to the main system configuration **the `nixos` user will be removed**.

You can generate a barebones system configuration by running `nixos-generate-config`. The
["Installing NixOS on a Raspberry Pi"](https://nix.dev/tutorials/installing-nixos-on-a-raspberry-pi)
guide contains many useful details on how to get a working system up, as well as example configs.

Once you have a valid configuration in `/etc/nixos/configuration.nix`, run `nixos-rebuild switch`
as `root`, and optionally run `nix-collect-garbage -d` to remove all the leftover stuff from the
installation that is not required.

For the Pi 3, see also
[this excellent blog post](https://citizen428.net/blog/installing-nixos-raspberry-pi-3)
which has step-by-step instructions for the whole process. (Note that this may be out of date as
of 2022.)

For the Pi 4, you might want to check
[these amazing instructions](https://gist.github.com/chrisanthropic/2e6d3645f20da8fd4c1f122113f89c06)
written by @chrisanthropic. If you're running out of space on your firmware partition, this Gist
also includes instructions on how to make an image with a bigger one.

## Troubleshooting

- If the execution fails due to missing permissions, sorry -- you need to be able to run containers
  with the `--privileged` Docker flag.
- If your system doesn't survive the first reboot after applying the final system configuration due
  to an error like "Did not find a cmdline Flattened Device Tree", please see #24 for troubleshooting
  steps and suggested configuration options to resolve the issue. Feel free to open another issue if
  the problem persists!
- If you get any error during the "copying store paths to image..." step
  (including `resize2fs` errors), this is most likely due to `cptofs` woes.
  The usage of `cptofs` has been removed in the `nixpkgs` tree since at least 2020, so this repo
  phased out any workaround for those issues. If you need to build an older NixOS version, check out
  an earlier commit of this repository.
- If you are running Docker Toolbox on Windows, you might encounter weird "file not found" errors
  when Nix attempts to find your configuration files. This is due to the fact that Docker Toolbox
  uses VirtualBox to run Docker and `C:\Users` is the only directory shared by default -- thus,
  if you're storing your files in any other path you might run into the issue.
  Follow [the instructions detailed in this great post](https://web.archive.org/web/20200521000637/https://headsigned.com/posts/mounting-docker-volumes-with-docker-toolbox-for-windows/)
  for ways to solve this. Thanks @dsferruzza!
- Failing commands like
  `bsdtar: Error opening archive: Can't initialize filter; unable to run program "zstd -d -qq"`
  might be due a preexisting alpine image. Delete it and run the script again.
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
    - download the specified version/checkout of `nixpkgs`. By default, this downloads `nixpkgs`
      23.11.
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
