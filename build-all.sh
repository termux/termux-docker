#!/usr/bin/env bash

set -e

OCI="docker"
case $1 in
	-p|--podman) OCI="podman" ;;
esac

if [ -n "${TERMUX_DOCKER_USE_SUDO-}" ]; then
	SUDO="sudo"
else
	SUDO=""
fi

for arch in "i686" "x86_64"; do
	$SUDO $OCI build \
		-t 'docker.io/xeffyr/termux:'"$arch" \
		-f Dockerfile \
		--build-arg BOOTSTRAP_ARCH="$arch" \
		.
done

docker tag docker.io/xeffyr/termux:i686 docker.io/xeffyr/termux:latest

if [ "${1-}" = "publish" ]; then
	$SUDO $OCI push 'docker.io/xeffyr/termux:latest'
	$SUDO $OCI push 'docker.io/xeffyr/termux:x86_64'
fi
