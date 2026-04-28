#!/system/bin/sh

if [ $# -lt 1 ]; then
	set -- login
fi

if [ "$(id -u)" != "0" ]; then
	echo "[!] Container is running as non-root, unable to start dnsmasq. DNS will be unavailable." >&2
	exec "$@"
fi

if [ -z "$(pidof dnsmasq)" ]; then
	rm -f /dnsmasq.pid
	/system/bin/sh -T /dev/ptmx -c "dnsmasq -u root -g root --pid-file=/dnsmasq.pid" >/dev/null 2>&1
fi

while [ ! -f /dnsmasq.pid ]; do
	sleep 1
done

exec /system/bin/su -s "$PREFIX/bin/env" system -- \
	-i \
	ANDROID_DATA="$ANDROID_DATA" \
	ANDROID_ROOT="$ANDROID_ROOT" \
	HOME="$HOME" \
	LANG="$LANG" \
	PATH="$PATH" \
	PREFIX="$PREFIX" \
	TMPDIR="$TMPDIR" \
	TZ="$TZ" \
	TERM="$TERM" \
	"$@"
