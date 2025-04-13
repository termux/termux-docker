#!/system/bin/sh

if [ $# -lt 1 ]; then
	set -- login
fi

if [ "$(id -u)" != "0" ]; then
	echo "Failure: /entrypoint_root.sh must be started as root." >&2
	exit 1
fi

if [ -z "$(pidof dnsmasq)" ]; then
	/system/bin/sh -T /dev/ptmx -c "dnsmasq -u root -g root --pid-file=/dnsmasq.pid" >/dev/null 2>&1
	sleep 1
	if [ -z "$(pidof dnsmasq)" ]; then
		echo "[!] Failed to start dnsmasq, host name resolution may fail." >&2
	fi
fi

exec "$@"
