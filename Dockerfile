##############################################################################
# Bootstrap Termux environment.
FROM scratch AS bootstrap

ARG TERMUX_DOCKER__ROOTFS
ARG TERMUX__PREFIX
ARG TERMUX__CACHE_DIR

# Install generated rootfs containing:
# - termux bootstrap
# - aosp-libs (bionic libc, linker, boringssl, zlib, libicuuc, debuggerd)
# - aosp-utils (toybox, mksh, iputils)
# - libandroid-stub
# - dnsmasq
# Since /system is now a symbolic link to $PREFIX/opt/aosp,
# which has contents that can be updated by the system user via apt,
# the entire rootfs is now owned by the system user (1000:1000).
COPY --chown=1000:1000 ${TERMUX_DOCKER__ROOTFS} /

# Docker uses /bin/sh by default, but we don't have it.
ENV PATH=/system/bin
SHELL ["sh", "-c"]

# Install updates and cleanup
# Start dnsmasq to resolve hostnames, and,
# for some reason the -c argument of toybox-su is not working,
# so this odd-looking script forces the update process
# to work using the -s argument of toybox-su instead, which is working.
RUN sh -T /dev/ptmx -c "$TERMUX__PREFIX/bin/dnsmasq -u root -g root --pid-file=/dnsmasq.pid" && \
    sleep 1 && \
    echo '#!/system/bin/sh' > /update.sh && \
    echo "PATH=$TERMUX__PREFIX/bin" >> /update.sh && \
    echo 'apt update' >> /update.sh && \
    echo 'apt upgrade -o Dpkg::Options::=--force-confnew -y' >> /update.sh && \
    chmod +x /update.sh && \
    su system -s /update.sh && \
    rm -f /update.sh && \
    rm -rf "${TERMUX__PREFIX}"/var/lib/apt/* && \
    rm -rf "${TERMUX__PREFIX}"/var/log/apt/* && \
    rm -rf "${TERMUX__CACHE_DIR}"/apt/*

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
