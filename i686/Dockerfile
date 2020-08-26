FROM scratch

ENV ANDROID_DATA     /data
ENV ANDROID_ROOT     /system
ENV HOME             /data/data/com.termux/files/home
ENV LANG             en_US.UTF-8
ENV PREFIX           /data/data/com.termux/files/usr
ENV TMPDIR           /data/data/com.termux/files/usr/tmp
ENV TZ               UTC

# Temporary set PATH to /system/bin so we will be able to
# bootstrap Termux environment.
ENV PATH /system/bin
SHELL ["/system/bin/sh", "-c"]

# Bootstrapping Termux environment.
ADD http://dl.bintray.com/termux/bootstrap/bootstrap-i686-v27.zip /data/data/com.termux/files/bootstrap.zip
COPY i686/system /system
COPY common/static-dns-hosts.txt /system/etc/static-dns-hosts.txt

WORKDIR /data/data/com.termux/files
RUN busybox mkdir usr && busybox unzip -d usr bootstrap.zip

WORKDIR /data/data/com.termux/files/usr
RUN busybox cat SYMLINKS.txt | while read -r line; do \
        dest=$(echo "$line" | busybox awk -F '←' '{ print $1 }'); \
        link=$(echo "$line" | busybox awk -F '←' '{ print $2 }'); \
        echo "Creating symlink: $link --> $dest"; \
        busybox ln -s "$dest" "$link"; \
    done && \
    busybox find bin lib/apt lib/bash libexec -type f -exec busybox chmod 700 "{}" \; && \
    for p in ./share/doc/util-linux/getopt/getopt-parse.bash \
        ./share/doc/util-linux/getopt/getopt-parse.tcsh ./var/service/ftpd/run \
        ./var/service/telnetd/run; do \
        if [ -f "$p" ]; then busybox chmod 700 "$p"; fi; \
    done

WORKDIR /
RUN busybox mkdir -p /data/data/com.termux/files/home && \
    busybox rm -f /data/data/com.termux/files/bootstrap.zip && \
    busybox rm -f /data/data/com.termux/files/usr/SYMLINKS.txt

# Fix permissions.
RUN busybox find /data -type d -exec busybox chmod 755 "{}" \; && \
    busybox find /data/data/com.termux/files -type d -exec busybox chmod 700 "{}" \; && \
    busybox find /data/data/com.termux/files/usr -type f -executable -exec busybox chmod 700 "{}" \; && \
    busybox find /data/data/com.termux/files/usr -type f ! -executable -exec busybox chmod 600 "{}" \; && \
    busybox chown -Rh 1000:1000 /data && \
    busybox find /system -type d -exec busybox chmod 755 "{}" \; && \
    busybox find /system -type f -executable -exec busybox chmod 755 "{}" \; && \
    busybox find /system -type f ! -executable -exec busybox chmod 644 "{}" \; && \
    busybox chown -Rh 0:0 /system && \
    busybox chown 1000:1000 /system/etc/hosts /system/etc/static-dns-hosts.txt

# Termux doesn't use these directories, but create them for compatibility
# when executing stuff like package tests.
RUN busybox ln -sf /data/data/com.termux/files/usr/bin /bin && \
    busybox ln -sf /data/data/com.termux/files/usr /usr && \
    busybox mkdir -p -m 1777 /tmp

# Switch to Termux environment.
WORKDIR /data/data/com.termux/files/home
USER 1000:1000
ENV PATH /data/data/com.termux/files/usr/bin:/data/data/com.termux/files/usr/bin/applets

# Symlink static dns things into Termux prefix.
RUN ln -sf /system/bin/update-static-dns /data/data/com.termux/files/usr/bin/update-static-dns && \
    ln -sf /system/etc/static-dns-hosts.txt /data/data/com.termux/files/usr/etc/static-dns-hosts.txt

# Update static dns on shell session start.
RUN echo "echo -e 'Updating static DNS:\n' && /system/bin/update-static-dns && echo" > /data/data/com.termux/files/home/.bashrc

# Make sure static dns list is up-to-date.
RUN /system/bin/update-static-dns

# Install package updates.
RUN apt update && \
    yes | apt upgrade && \
    rm -f /data/data/com.termux/files/usr/var/log/apt/*

ENTRYPOINT /data/data/com.termux/files/usr/bin/login
