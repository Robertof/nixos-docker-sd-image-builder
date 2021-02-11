ARG IMAGE_BASE

FROM ${IMAGE_BASE}alpine:latest

ARG NIXPKGS_URL
ARG NIXPKGS_BRANCH
ARG APPLY_CPTOFS_PATCH
ARG DISABLE_ZFS_IN_INSTALLER

RUN apk add curl git sudo patch xz
RUN adduser -D nixos
RUN mkdir -m 0755 /nix
RUN chown nixos /nix

# Setup `sudo` to only allow access to `/bin/cp`. This is a bit of an hack, and unfortunately
# there is no way to use `setuid` as `cp` is symlinked to `busybox` in alpine.
# The following solves https://github.com/sudo-project/sudo/issues/42
RUN echo 'Set disable_coredump false' >> /etc/sudo.conf
RUN echo -e 'nixos ALL=(ALL) ALL\nnixos ALL=(root) NOPASSWD: /bin/cp' >> /etc/sudoers

COPY --chown=nixos:nixos *.sh /home/nixos/
COPY --chown=nixos:nixos aarch64-tester /home/nixos/
COPY --chown=nixos:nixos *.patch /home/nixos/

USER nixos
ENV USER=nixos

RUN sh $HOME/setup-image-user.sh
