{ ... }:

{
  # NixOS works out of the box with the `sd-image-aarch64` builder.
  imports = [
    <nixpkgs/nixos/modules/installer/sd-card/sd-image-aarch64-installer.nix>
  ];
}
