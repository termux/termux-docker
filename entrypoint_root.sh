#!/system/bin/sh

if [ $# -lt 1 ]; then
	set -- login
fi

if [ "$(id -u)" != "0" ]; then
	echo "Failure: /entrypoint_root.sh must be started as root." >&2
	exit 1
fi

exec "$@"
