#!/system/bin/sh
set -e

busybox mkdir -p /data/data/com.termux/cache
cd /data/data/com.termux/files
busybox mkdir home usr
busybox unzip -d usr bootstrap.zip
busybox rm -f bootstrap.zip

# Termux bootstrap archive does not store symlinks in raw form.
# Instead, it has a SYMLINKS.txt which contains the information about
# symlink paths and their targets.
cd /data/data/com.termux/files/usr
busybox cat SYMLINKS.txt | while read -r line; do
	dest=$(echo "$line" | busybox awk -F '←' '{ print $1 }')
	link=$(echo "$line" | busybox awk -F '←' '{ print $2 }')
	echo "Creating symlink: $link --> $dest"
	busybox ln -s "$dest" "$link"
done
busybox rm -f SYMLINKS.txt

# Set generic permissions.
busybox find /data -type d -exec busybox chmod 755 "{}" \;
busybox find /data/data/com.termux/files -type d -exec busybox chmod 700 "{}" \;
busybox find /data/data/com.termux/files/usr -type f -executable -exec busybox chmod 700 "{}" \;
busybox find /data/data/com.termux/files/usr -type f ! -executable -exec busybox chmod 600 "{}" \;
busybox chown -Rh 1000:1000 /data
busybox find /system -type d -exec busybox chmod 755 "{}" \;
busybox find /system -type f -executable -exec busybox chmod 755 "{}" \;
busybox find /system -type f ! -executable -exec busybox chmod 644 "{}" \;
busybox chown -Rh 0:0 /system

# These files should be writable by normal user.
busybox chown 1000:1000 /system/etc/hosts /system/etc/static-dns-hosts.txt

# This step should be kept in sync with bootstrap archive content.
busybox find bin lib/apt lib/bash libexec -type f -exec busybox chmod 700 "{}" \;
for p in ./share/doc/util-linux/getopt/getopt-parse.bash \
	./share/doc/util-linux/getopt/getopt-parse.tcsh \
	./var/service/ftpd/run ./var/service/telnetd/run; do
	if [ -f "$p" ]; then
		busybox chmod 700 "$p"
	fi
done

# Termux doesn't use these directories, but create them for compatibility
# when executing stuff like package tests.
busybox ln -sf /data/data/com.termux/files/usr/bin /bin
busybox ln -sf /data/data/com.termux/files/usr /usr
busybox mkdir -p -m 1777 /tmp

# Symlink static dns things into Termux prefix.
busybox ln -sf /system/bin/update-static-dns /data/data/com.termux/files/usr/bin/update-static-dns
busybox ln -sf /system/etc/static-dns-hosts.txt /data/data/com.termux/files/usr/etc/static-dns-hosts.txt

# Update static dns on shell session start.
echo "echo -e 'Updating static DNS:\n' && /system/bin/update-static-dns && echo" > /data/data/com.termux/files/home/.bashrc

# Let script delete itself.
busybox rm -f "$(busybox realpath "$0")"
