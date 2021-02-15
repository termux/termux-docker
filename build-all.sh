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

case "$(uname -m)" in
	aarch64) SYSTEM_TYPE="arm"; ARCHITECTURES=("aarch64" "arm");;
	armv7l|armv8l) SYSTEM_TYPE="arm"; ARCHITECTURES=("arm");;
	i686) SYSTEM_TYPE="x86"; ARCHITECTURES=("i686");;
	x86_64) SYSTEM_TYPE="x86"; ARCHITECTURES=("i686" "x86_64");;
	*)
		echo "'uname -m' returned unknown architecture"
		exit 1
		;;
esac

for arch in "${ARCHITECTURES[@]}"; do
	$SUDO $OCI build \
		-t 'docker.io/xeffyr/termux:'"$arch" \
		-f Dockerfile \
		--build-arg BOOTSTRAP_ARCH="$arch" \
		--build-arg SYSTEM_TYPE="$SYSTEM_TYPE" \
		.
	if [ "${1-}" = "publish" ]; then
		$SUDO $OCI push 'docker.io/xeffyr/termux:'"$arch"
	fi
done

if [ "$SYSTEM_TYPE" = "x86" ]; then
	docker tag docker.io/xeffyr/termux:i686 docker.io/xeffyr/termux:latest
	if [ "${1-}" = "publish" ]; then
		$SUDO $OCI push 'docker.io/xeffyr/termux:latest'
	fi
fi
