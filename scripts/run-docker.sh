#!/bin/sh
set -e -u

CONTAINER_HOME_DIR=/home/builder
UNAME=$(uname)
if [ "$UNAME" = Darwin ]; then
	# Workaround for mac readlink not supporting -f.
	REPOROOT=$PWD
else
	REPOROOT="$(dirname $(readlink -f $0))/../"
fi

: ${TERMUX_BUILDER_IMAGE_NAME:=termux/package-builder}
: ${CONTAINER_NAME:=termux-package-builder}

USER=builder

echo "Running container '$CONTAINER_NAME' from image '$TERMUX_BUILDER_IMAGE_NAME'..."

if [ "${GITHUB_EVENT_PATH-x}" != "x" ]; then
	# On CI/CD tty may not be available.
	DOCKER_TTY=""
else
	DOCKER_TTY=" --tty"
fi

docker start $CONTAINER_NAME >/dev/null 2>&1 || {
	echo "Creating new container..."
	docker run \
		--detach \
		--name $CONTAINER_NAME \
		--volume $REPOROOT:$CONTAINER_HOME_DIR/termux-packages \
		--tty \
		$TERMUX_BUILDER_IMAGE_NAME
	if [ "$UNAME" != Darwin ]; then
		if [ $(id -u) -ne 1000 -a $(id -u) -ne 0 ]; then
			echo "Changed builder uid/gid... (this may take a while)"
			docker exec $DOCKER_TTY $CONTAINER_NAME sudo chown -R $(id -u) $CONTAINER_HOME_DIR
			docker exec $DOCKER_TTY $CONTAINER_NAME sudo chown -R $(id -u) /data
			docker exec $DOCKER_TTY $CONTAINER_NAME sudo usermod -u $(id -u) builder
			docker exec $DOCKER_TTY $CONTAINER_NAME sudo groupmod -g $(id -g) builder
		fi
	fi
}

if [ "$#" -eq  "0" ]; then
	docker exec --interactive $DOCKER_TTY $CONTAINER_NAME bash
else
	docker exec --interactive $DOCKER_TTY $CONTAINER_NAME "$@"
fi
