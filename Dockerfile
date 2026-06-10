##############################################################################
# Bootstrap Termux environment.
FROM scratch AS bootstrap

ARG TERMUX_DOCKER__ROOTFS
ARG TERMUX__PREFIX
ARG TERMUX__CACHE_DIR

# Install generated rootfs containing:
# - termux bootstrap
# - aosp-libs (bionic libc, linker, boringssl, zlib, libicuuc, debuggerd, depends on resolv-conf)
# - aosp-utils (toybox, grep, mksh, iputils)
# - libandroid-stub
# Since /system is now a symbolic link to $PREFIX/opt/aosp,
# which has contents that can be updated by the system user via apt,
# the entire rootfs is now owned by the system user (1000:1000),
# except for /data and /data/data (see below)
COPY --chown=1000:1000 ${TERMUX_DOCKER__ROOTFS} /

# Docker uses /bin/sh by default, but we don't have it.
ENV PATH=${TERMUX__PREFIX}/bin
SHELL ["sh", "-c"]

# Prevent the unprivileged user from having read access to
# /data and /data/data just like all real Android devices
# this will enable termux-docker to reproduce bugs (for debugging and development)
# like this one:
# https://github.com/termux/termux-packages/issues/28433
# but unfortunately it won't enable termux-docker to reproduce bugs that actually
# require / to be inaccessible to reproduce, like this one:
# https://github.com/termux-user-repository/tur/issues/1897
# it doesn't seem possible to set chmod 771 persistently on /
# within docker, since it reverts to 755 immediately when the container is run.
RUN chown root:root /data/ /data/data/
RUN chmod 771 /data/ /data/data/

# Install updates and cleanup
USER 1000:1000
RUN . $TERMUX__PREFIX/bin/termux-setup-package-manager && \
    if [ "$TERMUX_APP_PACKAGE_MANAGER" = "apt" ]; then \
        apt update && \
        apt upgrade -o Dpkg::Options::=--force-confnew -y; \
    elif [ "$TERMUX_APP_PACKAGE_MANAGER" = "pacman" ]; then \
        pacman-key --init && \
        pacman-key --populate && \
        pacman -Syyu --noconfirm; \
    fi && \
    rm -rf "${TERMUX__PREFIX}"/var/lib/apt/* \
        "${TERMUX__PREFIX}"/var/log/apt/* \
        "${TERMUX__CACHE_DIR}"/apt/* \
        "${TERMUX__PREFIX}"/var/cache/pacman/pkg/* \
        "${TERMUX__PREFIX}"/var/log/pacman.log

##############################################################################
# Create final image.
FROM scratch

ARG TERMUX__PREFIX
ARG TERMUX__HOME

ENV ANDROID_DATA=/data
ENV ANDROID_ROOT=/system
ENV HOME=${TERMUX__HOME}
ENV LANG=en_US.UTF-8
ENV PATH=${TERMUX__PREFIX}/bin
ENV PREFIX=${TERMUX__PREFIX}
ENV TMPDIR=${TERMUX__PREFIX}/tmp
ENV TZ=UTC
ENV TERM=xterm

COPY --from=bootstrap / /

WORKDIR ${TERMUX__HOME}
SHELL ["sh", "-c"]

ENTRYPOINT ["/entrypoint.sh"]
CMD ["login"]
