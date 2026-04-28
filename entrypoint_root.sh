#!/system/bin/sh

if [ $# -lt 1 ]; then
	set -- login
fi

if [ "$(id -u)" != "0" ]; then
	echo "Failure: /entrypoint_root.sh must be started as root." >&2
	exit 1
fi

if [ -z "$(pidof dnsmasq)" ]; then
	rm -f /dnsmasq.pid
	/system/bin/sh -T /dev/ptmx -c "dnsmasq -u root -g root --pid-file=/dnsmasq.pid" >/dev/null 2>&1
fi

while [ ! -f /dnsmasq.pid ]; do
	sleep 1
done

exec "$@"
