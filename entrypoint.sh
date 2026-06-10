#!/system/bin/sh

if [ $# -lt 1 ]; then
	set -- login
fi

if [ "$(id -u)" != "0" ]; then
	exec "$@"
fi

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
