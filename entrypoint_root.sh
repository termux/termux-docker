#!/system/bin/sh

if [ "$(id -u)" != "0" ]; then
	echo "Failure: /entrypoint_root.sh must be started as root." >&2
	exit 1
fi

if [ -z "$(/system/bin/busybox pidof dnsmasq)" ]; then
	/system/bin/mksh -T /dev/ptmx -c "/system/bin/dnsmasq -u root -g root --pid-file /dnsmasq.pid" >/dev/null 2>&1
	sleep 1
	if [ -z "$(/system/bin/busybox pidof dnsmasq)" ]; then
		echo "[!] Failed to start dnsmasq, host name resolution may fail." >&2
	fi
fi

if [ $# -ge 1 ]; then
	exec "$@"
else
	exec /data/data/com.termux/files/usr/bin/login
fi
