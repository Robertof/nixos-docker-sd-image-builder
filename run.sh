#!/bin/sh

set -u

if ! command -v "docker-compose" >/dev/null 2>&1; then
  echo "error: docker-compose is required to be in \$PATH to run this" >&2
  echo "install instructions: https://docs.docker.com/compose/install/" >&2
  exit 1
fi

echo "detecting architecture..."

# Image base to use. The trick to allow this to work painlessly on both x86 and AArch64 is just
# a magic trick which involves prepending `arm64v8/` when building natively.
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
  WANTS_EMULATION=y
  ;;
esac

# Default 
readonly COMPOSE_ACTION="${1-up}"
[ "$#" -ne 0 ] && shift

COMPOSE_ARGS="-f ./docker/docker-compose.yml"
[ -n "$WANTS_EMULATION" ] && COMPOSE_ARGS="$COMPOSE_ARGS -f ./docker/docker-compose.emulation.yml"

set -x
docker-compose $COMPOSE_ARGS $COMPOSE_ACTION "$@"
