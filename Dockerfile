##############################################################################
# Bootstrap Termux environment.
FROM scratch AS bootstrap

ARG BOOTSTRAP_VERSION=2021.11.06-r1
ARG BOOTSTRAP_ARCH=i686
ARG SYSTEM_TYPE=x86

# Docker uses /bin/sh by default, but we don't have it currently.
SHELL ["/system/bin/sh", "-c"]
ENV PATH /system/bin

# Copy libc, linker and few utilities.
COPY /system/$SYSTEM_TYPE /system

# Static DNS hosts: as our system does not have a DNS resolver, we will
# have to resolve domains manually and fill /system/etc/hosts.
COPY /static-dns-hosts.txt /system/etc/static-dns-hosts.txt

# Extract bootstrap archive and create symlinks.
ADD https://github.com/termux/termux-packages/releases/download/bootstrap-$BOOTSTRAP_VERSION/bootstrap-$BOOTSTRAP_ARCH.zip /bootstrap.zip
RUN busybox mkdir -p /data/data/com.termux/files && \
    cd /data/data/com.termux/files && \
    busybox mkdir ../cache ./usr ./home && \
    busybox unzip -d usr /bootstrap.zip && \
    busybox rm /bootstrap.zip && \
    cd ./usr && \
    busybox cat SYMLINKS.txt | while read -r line; do \
      dest=$(echo "$line" | busybox awk -F '←' '{ print $1 }'); \
      link=$(echo "$line" | busybox awk -F '←' '{ print $2 }'); \
      busybox ln -s "$dest" "$link"; \
    done && \
    busybox rm SYMLINKS.txt && \
    busybox ln -s /data/data/com.termux/files/usr /usr && \
    busybox ln -s /data/data/com.termux/files/usr/bin /bin && \
    busybox ln -s /data/data/com.termux/files/usr/tmp /tmp

# Set ownership and file access modes:
# * User content is owned by 1000:1000.
# * Termux file modes are set only for user.
# * Rest is owned by root and has 755/644 modes.
RUN busybox chown -Rh 0:0 /system && \
    busybox chown -Rh 1000:1000 /data/data/com.termux && \
    busybox chown 1000:1000 /system/etc/hosts /system/etc/static-dns-hosts.txt && \
    busybox find /system -type d -exec busybox chmod 755 "{}" \; && \
    busybox find /system -type f -executable -exec busybox chmod 755 "{}" \; && \
    busybox find /system -type f ! -executable -exec busybox chmod 644 "{}" \; && \
    busybox find /data -type d -exec busybox chmod 755 "{}" \; && \
    busybox find /data/data/com.termux/files -type f -o -type d -exec busybox chmod g-rwx,o-rwx "{}" \; && \
    cd /data/data/com.termux/files/usr && \
    busybox find ./bin ./lib/apt ./lib/bash ./libexec -type f -exec busybox chmod 700 "{}" \;

# Use utilities from Termux and switch user to non-root.
ENV PATH /data/data/com.termux/files/usr/bin
SHELL ["/data/data/com.termux/files/usr/bin/sh", "-c"]
USER 1000:1000

# Update static DNS cache on login. Also symlink script and host list to prefix.
RUN echo "echo -e 'Updating static DNS:\n' && /system/bin/update-static-dns && echo" \
    > /data/data/com.termux/files/home/.bashrc && \
    ln -s /system/bin/update-static-dns /data/data/com.termux/files/usr/bin/update-static-dns && \
    ln -s /system/etc/static-dns-hosts.txt /data/data/com.termux/files/usr/etc/static-dns-hosts.txt

# Update static DNS cache, install updates and cleanup.
RUN /system/bin/update-static-dns && \
    apt update && \
    apt upgrade -o Dpkg::Options::=--force-confnew -yq && \
    rm -rf /data/data/com.termux/files/usr/var/lib/apt/* && \
    rm -rf /data/data/com.termux/files/usr/var/log/apt/* && \
    rm -rf /data/data/com.termux/cache/apt/*

##############################################################################
# Create final image.
FROM scratch

ENV ANDROID_DATA     /data
ENV ANDROID_ROOT     /system
ENV HOME             /data/data/com.termux/files/home
ENV LANG             en_US.UTF-8
ENV PATH             /data/data/com.termux/files/usr/bin
ENV PREFIX           /data/data/com.termux/files/usr
ENV TMPDIR           /data/data/com.termux/files/usr/tmp
ENV TZ               UTC

COPY --from=bootstrap / /

WORKDIR /data/data/com.termux/files/home
SHELL ["/data/data/com.termux/files/usr/bin/sh", "-c"]
USER 1000:1000

CMD ["/data/data/com.termux/files/usr/bin/login"]
