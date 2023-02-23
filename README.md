# Termux environment for Docker/Podman.

A [Termux](https://termux.com) environment packaged into Docker image.
Environment doesn't have Android runtime components, so certain things will
not be available (DalvikVM, OpenSLES, etc...).

## How to use

### Requirements

You should have a properly configured and running Docker or Podman
container systems. Further instructions will provide examples only for
Docker.

### Basic usage

This will start interactive login shell. Everything will look like in a
normal Termux installation.

```.sh
docker run -it termux/termux-docker:latest
```

When using the tag `latest`, container will be 32 bit (i686 architecture).

Other architecture can be installed using a different tags. Available
tags:

- `aarch64`
- `arm`
- `i686` (`latest`)
- `x86_64`

If architecture is not compatible with host, the additional setup will
be needed. Read this document further to learn how you can run containers
of incompatible CPU architecture.

**Important note**: do not pass `--user` option to Docker command line.
The initial user of container must be root. Otherwise DNS will be broken
because of `dnsmasq` server failure.

### Running ARM containers on x86 host

In order to run AArch64 container on x86(64) host, you need to setup
QEMU emulator through binfmt_misc. This can be easily done by one
command:

```.sh
docker run --rm --privileged aptman/qus -s -- -p aarch64 arm
```

Note that AArch64 and ARM containers work properly only in privileged
mode. If you want your containers to have standard privileges, a custom
seccomp profile is required.

Variant with privileged container:

```.sh
docker run -it --privileged termux/termux-docker:aarch64
```

Variant with seccomp unconfined profile:

```.sh
docker run -it --security-opt seccomp:unconfined termux/termux-docker:aarch64
```

### Non-interactive execution of commands

You can run commands in non-interactive mode. Just append them to Docker
command line.

Example:

```.sh
docker run -it --rm termux/termux-docker:latest bash -c "apt update && apt install -yq clang"
```

### Root shell

By default root shell is disabled in container as Termux doesn't really
support usage of package manager under root account. In cases where you
really need shell with root privileges, entrypoint should be overridden.

The provided images have 2 entry points:

- `/entrypoint.sh` - the standard one which drops privileges to `system`
  user.
- `/entrypoint_root.sh` - alternate entrypoint that does not drop privileges.

Usage example:

```.sh
docker run -it --entrypoint /entrypoint_root.sh termux/termux-docker:latest
```

## Known issues

There a number of known issues which may not be resolved:

* ARM containers may require a custom seccomp profile to remove restrictions from
  `personality()` system call.

* When running certain multi threaded program in 32bit containers, the PIDs can 
  balloon and easily exceed libc's limit. The only way to fix this is to set 
  `/proc/sys/kernel/pid_max` to 65536. See [termux-docker#40](https://github.com/termux/termux-docker/issues/40).
