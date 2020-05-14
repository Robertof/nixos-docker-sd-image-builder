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

  sdImage = {
    firmwareSize = 128;
    # /var/empty is needed for some services, such as sshd
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
