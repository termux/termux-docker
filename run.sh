#!/usr/bin/env bash

case $1 in
    -p|--podman) shopt -s expand_aliases ; alias docker="podman" ;;
esac

if [ "$(basename "$0")" = "run-x86_64.sh" ]; then
	CONTAINER_NAME="termux-x86_64"
	DOCKER_IMAGE_NAME="docker.io/xeffyr/termux:x86_64"
else
	CONTAINER_NAME="termux-i686"
	DOCKER_IMAGE_NAME="docker.io/xeffyr/termux:latest"
fi

docker start "$CONTAINER_NAME" > /dev/null 2> /dev/null || {
	echo "Creating new container..."
	docker run \
		--detach \
		--name "$CONTAINER_NAME" \
		--tty \
		"$DOCKER_IMAGE_NAME"
}

docker exec --interactive --tty "$CONTAINER_NAME" \
	/data/data/com.termux/files/usr/bin/login
