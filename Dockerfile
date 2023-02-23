##############################################################################
# Bootstrap Termux environment.
FROM scratch AS bootstrap

ARG BOOTSTRAP_VERSION=2023.02.19-r1%2Bapt-android-7
ARG BOOTSTRAP_ARCH=i686
ARG SYSTEM_TYPE=x86

# Docker uses /bin/sh by default, but we don't have it currently.
SHELL ["/system/bin/sh", "-c"]
ENV PATH /system/bin

# Copy libc, linker and few utilities.
COPY /system/$SYSTEM_TYPE /system

# Copy entrypoint script.
COPY /entrypoint.sh /entrypoint.sh
COPY /entrypoint_root.sh /entrypoint_root.sh

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

# Link some utilities to busybox.
# Some utilities in $PREFIX are actually a wrapper of the same binary
# from /system/bin. See termux-tools/build.sh#L29.
RUN for tool in df mount ping ping6 su top umount; do \
        busybox ln -s /system/bin/busybox /system/bin/$tool; \
    done

# Set ownership and file access modes:
# * User content is owned by 1000:1000.
# * Termux file modes are set only for user.
# * Rest is owned by root and has 755/644 modes.
RUN busybox chown -Rh 0:0 /system && \
    busybox chown -Rh 1000:1000 /data/data/com.termux && \
    busybox ln -s /system/etc/passwd /etc/passwd && \
    busybox ln -s /system/etc/group /etc/group && \
    busybox find /system -type d -exec busybox chmod 755 "{}" \; && \
    busybox find /system -type f -executable -exec busybox chmod 755 "{}" \; && \
    busybox find /system -type f ! -executable -exec busybox chmod 644 "{}" \; && \
    busybox find /data -type d -exec busybox chmod 755 "{}" \; && \
    busybox find /data/data/com.termux/files -type f -o -type d -exec busybox chmod g-rwx,o-rwx "{}" \; && \
    cd /data/data/com.termux/files/usr && \
    busybox find ./bin ./lib/apt ./libexec -type f -exec busybox chmod 700 "{}" \;

# Install updates and cleanup when not building for arm.
ENV PATH /data/data/com.termux/files/usr/bin
RUN if [ ${SYSTEM_TYPE} = 'arm' ]; then exit; else \
    /system/bin/mksh -T /dev/ptmx -c "/system/bin/dnsmasq -u root -g root --pid-file /dnsmasq.pid" && sleep 1 && \
    su - system -c "/data/data/com.termux/files/usr/bin/apt update" && \
    su - system -c "/data/data/com.termux/files/usr/bin/apt upgrade -o Dpkg::Options::=--force-confnew -yq" && \
    rm -rf /data/data/com.termux/files/usr/var/lib/apt/* && \
    rm -rf /data/data/com.termux/files/usr/var/log/apt/* && \
    rm -rf /data/data/com.termux/cache/apt/* ;\
    fi

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

ENTRYPOINT ["/entrypoint.sh"]
CMD ["/data/data/com.termux/files/usr/bin/login"]
