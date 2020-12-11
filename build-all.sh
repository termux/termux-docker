#!/usr/bin/env bash

if [ -n "${TERMUX_DOCKER_USE_SUDO-}" ]; then
	SUDO="sudo"
else
	SUDO=""
fi

$SUDO docker build -t 'xeffyr/termux:latest' -f Dockerfile.32bit .
$SUDO docker build -t 'xeffyr/termux:x86_64' -f Dockerfile.64bit .

if [ "${1-}" = "publish" ]; then
	$SUDO docker push 'xeffyr/termux:latest'
	$SUDO docker push 'xeffyr/termux:x86_64'
fi
