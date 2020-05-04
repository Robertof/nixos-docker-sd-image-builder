FROM alpine:latest

ARG NIXPKGS_URL
ARG NIXPKGS_BRANCH
ARG APPLY_RESIZE2FS_PATCH

RUN apk add curl git
RUN adduser -D nixos
RUN mkdir -m 0755 /nix
RUN chown nixos /nix

COPY --chown=nixos:nixos *.sh /home/nixos/
COPY --chown=nixos:nixos aarch64-tester /home/nixos

USER nixos
ENV USER=nixos

RUN sh $HOME/setup-image-user.sh
