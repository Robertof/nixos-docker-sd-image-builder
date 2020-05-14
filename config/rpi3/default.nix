{ ... }:

{
  # NixOS works out of the box with the `sd-image-aarch64` builder.
  imports = [
    <nixpkgs/nixos/modules/installer/cd-dvd/sd-image-aarch64.nix>
  ];
}
