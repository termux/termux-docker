FROM scratch

ARG BOOTSTRAP_VERSION=2021.06.04-r1
ARG BOOTSTRAP_ARCH=i686
ARG SYSTEM_TYPE=x86

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
ADD https://github.com/termux/termux-packages/releases/download/bootstrap-$BOOTSTRAP_VERSION/bootstrap-$BOOTSTRAP_ARCH.zip /data/data/com.termux/files/bootstrap.zip
COPY /system/$SYSTEM_TYPE /system
RUN /system/setup-termux.sh

# Switch to Termux environment.
WORKDIR /data/data/com.termux/files/home
USER 1000:1000
ENV PATH /data/data/com.termux/files/usr/bin

# Install package updates.
RUN /system/bin/update-static-dns && \
    apt update && \
    yes | apt upgrade && \
    rm -rf /data/data/com.termux/files/usr/var/log/apt/* && \
    rm -rf /data/data/com.termux/cache/apt/*

ENTRYPOINT /data/data/com.termux/files/usr/bin/login
