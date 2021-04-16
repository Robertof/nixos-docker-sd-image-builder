# This is an hybrid of the original `sd-image-raspberrypi4` from:
# https://github.com/NixOS/nixpkgs/blob/9a0b7457d304b85444ac07cbb0c0aa45cf453d63/nixos/modules/installer/cd-dvd/sd-image-raspberrypi4.nix
# And this PR: https://github.com/NixOS/nixpkgs/pull/78090
# NOTE: once the mainline kernel boots on the Pi 4 this won't be necessary anymore.

{ config, lib, pkgs, ... }:

{
  imports = [
    <nixpkgs/nixos/modules/profiles/base.nix>
    <nixpkgs/nixos/modules/profiles/installation-device.nix>
    <nixpkgs/nixos/modules/installer/cd-dvd/sd-image.nix>
  ];

  boot.loader.grub.enable = false;
  boot.loader.raspberryPi.enable = true;
  boot.loader.raspberryPi.version = 4;
  boot.kernelPackages = pkgs.linuxPackages_rpi4;

  boot.consoleLogLevel = lib.mkDefault 7;

  # Increase `cma` to 64M to allow to use all of the RAM.
  # NOTE: this disables the serial console. Add
  # "console=ttyS0,115200n8" "console=ttyAMA0,115200n8" to restore.
  boot.kernelParams = [
    # Increase `cma` to 64M to allow to use all of the RAM.
    "cma=64M"
    "console=tty0"
    # To enable the serial console, uncomment the following line.
    # "console=ttyS0,115200n8" "console=ttyAMA0,115200n8"
    # Some Raspberry Pi 4s fail to boot correctly without the following. See
    # issue #20.
    "8250.nr_uarts=1"
  ];

  # Remove some kernel modules added for AllWinner SOCs that are not available
  # for RPi's kernel.
  # See: https://git.io/JOlb3
  boot.initrd.availableKernelModules = [
    # Allows early (earlier) modesetting for the Raspberry Pi
    "vc4" "bcm2835_dma" "i2c_bcm2835"
  ];

  sdImage = {
    # This might need to be increased when deploying multiple configurations.
    firmwareSize = 128;
    # TODO: check if needed.
    populateFirmwareCommands =
      "${config.system.build.installBootLoader} ${config.system.build.toplevel} -d ./firmware";
    # /var/empty is needed for some services, such as sshd
    # XXX: This might not be needed anymore, adding to be extra sure.
    populateRootCommands = "mkdir -p ./files/var/empty";
  };

  # the installation media is also the installation target,
  # so we don't want to provide the installation configuration.nix.
  installer.cloneConfig = false;

  fileSystems = lib.mkForce {
      # There is no U-Boot on the Pi 4, thus the firmware partition needs to be mounted as /boot.
      "/boot" = {
          device = "/dev/disk/by-label/FIRMWARE";
          fsType = "vfat";
      };
      "/" = {
          device = "/dev/disk/by-label/NIXOS_SD";
          fsType = "ext4";
      };
  };
}
