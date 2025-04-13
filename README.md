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

When using the tag `latest`, container will be 64 bit (x86_64 architecture).

Other architecture can be installed using a different tags. Available
tags:

- `aarch64`
- `arm`
- `i686`
- `x86_64` (`latest`)

If architecture is not compatible with host, the additional setup will
be needed. Read this document further to learn how you can run containers
of incompatible CPU architecture.

**Important note**: do not pass `--user` option to Docker command line.
The initial user of container must be root. Otherwise DNS will be broken
because of `dnsmasq` server failure.

### Running ARM containers

In order to run AArch64 container on x86(64) host, you need to setup
QEMU emulator through binfmt_misc. This can be easily done by one
command:

```.sh
docker run --rm --privileged aptman/qus -s -- -p aarch64 arm
```

Note that AArch64 and ARM containers sometimes work properly only in privileged
mode, even on some real ARM devices. If you want your containers to have standard privileges, a custom
seccomp profile or a custom build of Docker might be required. The custom build
of Docker limits the customizations to purely what is necessary for
the `personality()` system call, leaving the security settings of all other system
calls untouched.

Variant with privileged container:

```.sh
docker run -it --privileged termux/termux-docker:aarch64
```

Variant with seccomp unconfined profile:

```.sh
docker run -it --security-opt seccomp:unconfined termux/termux-docker:aarch64
```

Variant with custom build of Docker:

> [!NOTE]
> Example with Debian bookworm `armhf` host and the `docker.io` package. Assumes that [`deb-src` URIs](https://wiki.debian.org/Packaging/SourcePackage?action=show&redirect=SourcePackage#With_apt-get_source) and the [`devscripts` package](https://wiki.debian.org/Packaging#Suggested_tools_to_create_an_environment_for_packaging) are already installed, and that the current user is a member of the `docker` group.

```.sh
sudo apt build-dep docker.io
apt source docker.io
cp /path/to/termux-docker/custom-docker-with-unrestricted-personality.patch docker.io-*/debian/patches/
echo 'custom-docker-with-unrestricted-personality.patch' >> docker.io-*/debian/patches/series 
cd docker.io-*/
DEB_BUILD_OPTIONS=nocheck debuild -b -uc -us
rm ../golang*
sudo apt install ../*.deb
docker run -it termux/termux-docker:arm
```

You might then want to temporarily use `sudo apt-mark hold docker.io` to ensure the package is not automatically upgraded, causing termux-docker to stop working on the device in the future, but **not upgrading can be a security risk**. If using the patch, it is recommended to patch and recompile the Docker daemon after every upgrade.

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

## Building image

Docker:

```.sh
./generate.sh
```

Podman:

```.sh
./generate.sh --podman
```

## Known issues

There a number of known issues which may not be resolved:

* ARM containers might require a custom seccomp profile or custom build of Docker to remove restrictions from the
  `personality()` system call.

* When running certain multi threaded program in 32bit containers, the PIDs can 
  balloon and easily exceed libc's limit. The only way to fix this is to set 
  `/proc/sys/kernel/pid_max` to 65535. See [termux-docker#40](https://github.com/termux/termux-docker/issues/40).
