#!/usr/bin/env bash

OCI="docker"
case $1 in
    -p|--podman) OCI="podman" ;;
esac

if [ -n "${TERMUX_DOCKER_USE_SUDO-}" ]; then
	SUDO="sudo"
else
	SUDO=""
fi

$SUDO $OCI build -t 'docker.io/xeffyr/termux:latest' -f Dockerfile.32bit .
$SUDO $OCI build -t 'docker.io/xeffyr/termux:x86_64' -f Dockerfile.64bit .

if [ "${1-}" = "publish" ]; then
	$SUDO $OCI push 'docker.io/xeffyr/termux:latest'
	$SUDO $OCI push 'docker.io/xeffyr/termux:x86_64'
fi
