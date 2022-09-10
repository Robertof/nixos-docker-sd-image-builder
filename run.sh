#!/bin/sh
set -u

DOCKER_COMPOSE="docker-compose"

if ! command -v $DOCKER_COMPOSE >/dev/null 2>&1; then
  # Verify if this system is using docker-compose v2, which on some systems is only exposed
  # as a sub-command of docker.
  if command -v "docker" >/dev/null 2>&1 && docker compose version --short >/dev/null 2>&1; then
    echo "note: using 'compose' docker subcommand rather than 'docker-compose'"

    DOCKER_COMPOSE="docker compose"
  else
    echo "error: docker-compose is required to be in \$PATH to run this" >&2
    echo "install instructions: https://docs.docker.com/compose/install/" >&2
    exit 1
  fi
fi

echo "detecting architecture..."

# Image base to use. The magic trick that allows this to work painlessly on both x86 and AArch64 is
# just the `arm64v8/` prefix when building natively.
export IMAGE_BASE=

# Whether to evaluate `docker-compose.emulation.yml`.
WANTS_EMULATION=

case "$(uname -m)" in
arm|armel|armhf|arm64|armv[4-9]*l|aarch64)
  # This will use images prefixed with `arm64v8/`, which run natively.
  export IMAGE_BASE=arm64v8/
  echo " detected native ARM architecture, disabling emulation and using image base $IMAGE_BASE"
  ;;
*)
  echo " detected non-ARM architecture, enabling emulation"
  # [!] Leave WANTS_EMULATION= blank if you don't want to setup emulation with QEMU.
  WANTS_EMULATION=y
  ;;
esac

# Default 
readonly COMPOSE_ACTION="${1-up}"
[ "$#" -ne 0 ] && shift

COMPOSE_ARGS="-f ./docker/docker-compose.yml"
[ -n "$WANTS_EMULATION" ] && COMPOSE_ARGS="$COMPOSE_ARGS -f ./docker/docker-compose.emulation.yml"

# backup the binary name to a separate variable
readonly DOCKER_COMPOSE_BIN="$DOCKER_COMPOSE"

# determine whether to use `sudo` or not
# thanks to masnagam/sbc-scripts for inspiration
if [ "$(uname)" = Linux ] && [ "$(id -u)" -ne 0 ] && ! id -nG | grep -q docker; then
  if command -v "sudo" >/dev/null 2>&1; then
    readonly DOCKER_COMPOSE="sudo $DOCKER_COMPOSE"
  else
    echo "warning: you might need to run this script as root"
  fi
fi

if [ -n "$WANTS_EMULATION" ] && [ "$COMPOSE_ACTION" = "up" ]; then
  echo "figuring out if docker-compose >= 2.0.0 workaround is needed..."
  COMPOSE_VERSION="$($DOCKER_COMPOSE_BIN version --short)"
  COMPOSE_VERSION="${COMPOSE_VERSION%%.*}" # extract major version
  COMPOSE_VERSION="${COMPOSE_VERSION#v}" # remove leading 'v'
  readonly COMPOSE_VERSION
  if [ "$COMPOSE_VERSION" -ge 2 ]; then
    echo "  detected docker-compose $COMPOSE_VERSION, pre-building images"
    $DOCKER_COMPOSE $COMPOSE_ARGS build
  fi
fi

set -x
$DOCKER_COMPOSE $COMPOSE_ARGS $COMPOSE_ACTION "$@"
