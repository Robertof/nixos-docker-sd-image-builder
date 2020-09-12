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
- **Raspberry Pi 4.** Please note that the latest Raspberry Pi 4 model with 8 GiB of RAM
  is supported upstream only when building an image from the unstable branch. To do that,
  open [`docker/docker-compose.yml`](docker/docker-compose.yml) and change `NIXPKGS_BRANCH`
  to `master`.

Any other device can be supported by changing the configuration files in [`config/`](config/).

## Getting started

###1. Clone this repo and cd in to it

```sh
git clone git@github.com:Robertof/nixos-docker-sd-image-builder.git && cd nixos-docker-sd-image-builder
```

###2. Config build image
```sh
vi config/sd-image.nix
```

- Choose the target device (default Raspberry PI 3)
```
  imports = [
    # uncomment the following to select target device
    # ./generic-aarch64
    # ./rpi4
    ./rpi3
  ];
  ```
- add your SSH key(s) by replacing the existing `ssh-ed25519 ...` placeholder.
```
users.extraUsers.nixos.openssh.authorizedKeys.keys = [
  "ssh-ed25519 AICxckLaE01uWBu327qvAu9rlCxckLaE0uWBu327qvAAAICxckLaD0KeCQRu9rld/tre rpi 3"
];
  ```
- [Optional] Config run.sh if you don't want to install QEMU
```sh
vi run.sh
  ```
If you don't want QEMU (GUI) make sure `WANTS_EMULATION=`
```
# Whether to evaluate `docker-compose.emulation.yml`.
# leave this blank if you don't want to install QEMU
WANTS_EMULATION=

case "$(uname -m)" in
arm|armel|armhf|arm64|armv[4-9]*l|aarch64)
  # This will use images prefixed with `arm64v8/`, which run natively.
  export IMAGE_BASE=arm64v8/
  echo " detected native ARM architecture, disabling emulation and using image base $IMAGE_BASE"
  ;;
*)
  echo " detected non-ARM architecture, enabling emulation"
  # leave this blank if you don't want to install QEMU
  WANTS_EMULATION=
  ;;
esac
```

Customize `sd-card.nix` (or add more files) as you like, they will be copied to the container.

_Protip: if you're building for a Raspberry Pi 4 and don't need ZFS, enable
`DISABLE_ZFS_IN_INSTALLER` in [`docker/docker-compose.yml`](docker/docker-compose.yml) to speed
up the build. Please note that if you have already executed `run.sh` once, you need to rebuild
the images after changing this flag using `./run.sh up --build`._

###3. Build image
Finally, ensure that your [Docker](https://www.docker.com/) is set up and you have a working
installation of [Docker Compose](https://docs.docker.com/compose/), then just run:

```sh
./run.sh
```

_If you encounter_ ```Error while copying store paths to image``` _refer to issue #1_

The script is just a wrapper around `docker-compose` which makes sure that the right parameters
are passed to it.

###4. Clean up
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

## Next steps

Once an image is produced by the container it's sufficient to flash it to the SD card of your
choice with any tool which can flash raw images onto block devices. There have been some reports
of issues using Etcher on macOS, thus it might be easier to just use
[`dd`](https://wiki.archlinux.org/index.php/USB_flash_installation_media#Using_dd) or [`Raspberry Pi Imager`](https://www.raspberrypi.org/blog/raspberry-pi-imager-imaging-utility/)(GUI).

Hopefully, the flashed SD card should _just work_ on your device.
Connect device to local ethernet and ssh with private key (Default user is nixos)
```sh
ssh -i /Users/me/.ssh/id_ed25519-rpi nixos@192.168.0.157
```
##Resource
The
[unofficial wiki](https://nixos.wiki/wiki/NixOS_on_ARM/Raspberry_Pi) contains lots of resources
for possible things you might need or that might go wrong when using NixOS on a Raspberry Pi.
Check out the page for [all ARM devices](https://nixos.wiki/wiki/NixOS_on_ARM) too.

### Platform-specific steps

#### Raspberry Pi 3 and 4

Once your Pi boots and you're logged in, you can generate a barebones configuration using
`nixos-generate-config`.

Please keep in mind the following:

- the _installer configuration_ (which is the one you edited in the [`config/`](config/) folder) is
  _different_ than the system configuration. The installer configuration is only used to build
  the image -- **using an installer configuration on a production system is an error and will
  lead to weirdness.**
- the _system configuration_ will _not_ inherit from the installer configuration, thus any
  relevant options (such as users, SSH keys, networking etc.) have to be configured again. Please
  note that once you switch to the main system configuration **the `nixos` user will be removed**.

That being said, here are some example _system configurations_ that are mostly ready to use for
both the Pi 3 and Pi 4:

<details>
  <summary>Example configuration for the Pi 3</summary>
  
  ```nix
  # Please read the comments!
  { config, pkgs, lib, ... }:
  {
    # Boot
    boot.loader.grub.enable = false;
    boot.loader.raspberryPi.enable = true;
    boot.loader.raspberryPi.version = 3;
    boot.loader.raspberryPi.uboot.enable = true;

    # Kernel configuration
    boot.kernelPackages = pkgs.linuxPackages_latest;
    boot.kernelParams = ["cma=32M"];

    # Enable additional firmware (such as Wi-Fi drivers).
    hardware.enableRedistributableFirmware = true;

    # Filesystems
    fileSystems = {
      "/" = {
        device = "/dev/disk/by-label/NIXOS_SD";
        fsType = "ext4";
      };
    };
    swapDevices = [ { device = "/swapfile"; size = 1024; } ];

    # Networking (see official manual or `/config/sd-image.nix` in this repo for other options)
    networking.hostName = "nixpi"; # unleash your creativity!

    # Packages
    environment.systemPackages = with pkgs; [
      # customize as needed!
      vim git htop
    ];

    # Users
    # === IMPORTANT ===
    # Change `yourName` here with the name you'd like for your user!
    users.users.yourName = {
      isNormalUser = true;
      # Don't forget to change the home directory too.
      home = "/home/yourName";
      # This allows this user to use `sudo`.
      extraGroups = [ "wheel" ];
      # SSH authorized keys for this user.
      openssh.authorizedKeys.keys = [ "ssh-ed25519 ..." ];
    };

    # Miscellaneous
    time.timeZone = "Europe/Rome"; # you probably want to change this -- otherwise, ciao!
    services.openssh.enable = true;

    # WARNING: if you remove this, then you need to assign a password to your user, otherwise
    # `sudo` won't work. You can do that either by using `passwd` after the first rebuild or
    # by setting an hashed password in the `users.users.yourName` block as `initialHashedPassword`.
    security.sudo.wheelNeedsPassword = false;

    # Nix
    nix.gc.automatic = true;
    nix.gc.options = "--delete-older-than 30d";
    boot.cleanTmpDir = true;

    # https://nixos.wiki/wiki/FAQ/When_do_I_update_stateVersion
    system.stateVersion = "20.03";
  }
  ```
</details>

<details>
  <summary>Example configuration for the Pi 4</summary>
  
  ```nix
  # Please read the comments!
  { config, pkgs, lib, ... }:
  {
    # Boot
    boot.loader.grub.enable = false;
    boot.loader.raspberryPi.enable = true;
    boot.loader.raspberryPi.version = 4;

    # Kernel configuration
    boot.kernelPackages = pkgs.linuxPackages_rpi4;
    boot.kernelParams = ["cma=64M" "console=tty0"];

    # Enable additional firmware (such as Wi-Fi drivers).
    hardware.enableRedistributableFirmware = true;

    # Filesystems
    fileSystems = {
        # There is no U-Boot on the Pi 4 (yet) -- the firmware partition has to be mounted as /boot.
        "/boot" = {
            device = "/dev/disk/by-label/FIRMWARE";
            fsType = "vfat";
        };
        "/" = {
            device = "/dev/disk/by-label/NIXOS_SD";
            fsType = "ext4";
        };
    };

    swapDevices = [ { device = "/swapfile"; size = 1024; } ];

    # Networking (see official manual or `/config/sd-image.nix` in this repo for other options)
    networking.hostName = "nixpi"; # unleash your creativity!

    # Packages
    environment.systemPackages = with pkgs; [
      # customize as needed!
      vim git htop
    ];

    # Users
    # === IMPORTANT ===
    # Change `yourName` here with the name you'd like for your user!
    users.users.yourName = {
      isNormalUser = true;
      # Don't forget to change the home directory too.
      home = "/home/yourName";
      # This allows this user to use `sudo`.
      extraGroups = [ "wheel" ];
      # SSH authorized keys for this user.
      openssh.authorizedKeys.keys = [ "ssh-ed25519 ..." ];
    };

    # Miscellaneous
    time.timeZone = "Europe/Rome"; # you probably want to change this -- otherwise, ciao!
    services.openssh.enable = true;

    # WARNING: if you remove this, then you need to assign a password to your user, otherwise
    # `sudo` won't work. You can do that either by using `passwd` after the first rebuild or
    # by setting an hashed password in the `users.users.yourName` block as `initialHashedPassword`.
    security.sudo.wheelNeedsPassword = false;

    # Nix
    nix.gc.automatic = true;
    nix.gc.options = "--delete-older-than 30d";

    # https://nixos.wiki/wiki/FAQ/When_do_I_update_stateVersion
    system.stateVersion = "20.03";
  }
  ```
</details>

Once you have a valid configuration in `/etc/nixos/configuration.nix`, run `nixos-rebuild switch`
as `root`, and optionally run `nix-collect-garbage -d` to remove all the leftover stuff from the
installation that is not required.

For the Pi 3, see also
[this excellent blog post](https://citizen428.net/blog/installing-nixos-raspberry-pi-3)
which has step-by-step instructions for the whole process.

For the Pi 4, you might want to check
[these amazing instructions](https://gist.github.com/chrisanthropic/2e6d3645f20da8fd4c1f122113f89c06)
written by @chrisanthropic. If you're running out of space on your firmware partition, this Gist
also includes instructions on how to make an image with a bigger one.

## Troubleshooting

- If the execution fails due to missing permissions, sorry -- you need to be able to run containers
  with the `--privileged` Docker flag.
- If you get any error during the "copying store paths to image..." step, this is most likely due
  to `cptofs` running out of memory. The usage of `cptofs` has been removed in the `master` branch of
  `nixpkgs`, but it's possible to apply the individual patch that fixed the issue on the 20.03 release
  as well. Thus, _either_: (see #1)
  - set `NIXPKGS_BRANCH` to `master` in [`docker/docker-compose.yml`](docker/docker-compose.yml) and
    rerun with `./run.sh up --build`. **This will build an unstable NixOS build based on `master`.**
  - or uncomment `APPLY_CPTOFS_PATCH` in [`docker/docker-compose.yml`](docker/docker-compose.yml) and
    rerun with `./run.sh up --build`. This will apply [this patch](https://github.com/NixOS/nixpkgs/pull/82718)
    which replaces `cptofs` on top of your chosen branch.
  - or make sure you have enough memory/swap and disk space, as this can require up to 8 GiB of RAM
    and ~6-7 GiB of disk space.
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
