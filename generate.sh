#!/usr/bin/env bash

set -eu

cd "$(dirname "$(realpath "$0")")"

OCI="docker"
OCI_ARG="build"
case "${1-}" in
	-p|--podman) OCI="podman" ; OCI_ARG+=" --format docker" ;;
esac

if [ -n "${TERMUX_DOCKER_USE_SUDO-}" ]; then
	SUDO="sudo"
else
	SUDO=""
fi

# This determines the architecture of the image being built,
# but should also be an architecture that is compatible with the computer
# running this script, so that the RUN step in the Dockerfile
# can be used to ensure the packages preinstalled in the image are up-to-date.
if [ -z "${TERMUX_ARCH-}" ]; then
	TERMUX_ARCH="$(uname -m)"
fi

case "$TERMUX_ARCH" in
	aarch64)           TERMUX_ARCH="aarch64" PLATFORM_TAG="linux/arm64" ;;
	armv7l|armv8l|arm) TERMUX_ARCH="arm"     PLATFORM_TAG="linux/arm/v7" ;;
	x86_64)            TERMUX_ARCH="x86_64"  PLATFORM_TAG="linux/amd64" ;;
	i686)              TERMUX_ARCH="i686"    PLATFORM_TAG="linux/386" ;;
	*)
		echo "error: ${TERMUX_ARCH} is not a valid architecture!"
		exit 1
		;;
esac

PLATFORM_ARG=""
if [ "${OCI}" = "docker" ] && $OCI --help 2>&1 | grep -q buildx; then
	OCI_ARG="buildx ${OCI_ARG}"
	PLATFORM_ARG="--load --platform ${PLATFORM_TAG}"
fi

: "${TERMUX_PACKAGE_MANAGER:="apt"}"
case "${TERMUX_PACKAGE_MANAGER}" in
	apt)
		TERMUX_DOCKER__IMAGE_NAME="termux/termux-docker"
		TERMUX_DOCKER__BOOTSTRAP_VERSION="2023.02.19-r1%2Bapt-android-7"
		TERMUX_DOCKER__BOOTSTRAP_SRCURL="https://github.com/termux/termux-packages/releases/download/bootstrap-${TERMUX_DOCKER__BOOTSTRAP_VERSION}/bootstrap-${TERMUX_ARCH}.zip"
		declare -A REPO_BASE_URLS=(
			["main"]="https://packages-cf.termux.dev/apt/termux-main/dists/stable/main"
			["root"]="https://packages-cf.termux.dev/apt/termux-root/dists/root/stable"
		)
		;;
	pacman)
		TERMUX_DOCKER__IMAGE_NAME="termux/termux-docker-pacman"
		TERMUX_DOCKER__BOOTSTRAP_VERSION="2026.02.01-r1%2Bpacman-android-7"
		TERMUX_DOCKER__BOOTSTRAP_SRCURL="https://github.com/termux-pacman/termux-packages/releases/download/bootstrap-${TERMUX_DOCKER__BOOTSTRAP_VERSION}/bootstrap-${TERMUX_ARCH}.zip"
		declare -A REPO_BASE_URLS=(
			["main"]="https://service.termux-pacman.dev/main"
			["root"]="https://service.termux-pacman.dev/root"
		)
		;;
	*)
		echo "Unsupported package manager \"${TERMUX_PACKAGE_MANAGER}\". Only 'apt' and 'pacman' are supported."
		exit 1
		;;
esac

# packages that are extracted, along with their dependencies,
# on top of the bootstrap to form the termux-docker rootfs.
# libandroid-stub is described in multiple places as existing explicitly
# for use with termux-docker, so pulling it in here.
# dnsmasq will not get automatically updated during 'pkg upgrade' by the user
# after termux-docker has been installed, since root-repo is not installed for now
# to imply that other root-packages are not directly supported,
# but aosp-utils, aosp-libs and libandroid-stub will get automatically updated
# by user-invoked instances of 'pkg upgrade' since they are in the main repository.
TERMUX_DOCKER__DEPENDS="aosp-utils, libandroid-stub, dnsmasq"
TERMUX_APP__PACKAGE_NAME="com.termux"
TERMUX_APP__DATA_DIR="/data/data/$TERMUX_APP__PACKAGE_NAME"
TERMUX__PREFIX_SUBDIR="usr"
TERMUX__HOME_SUBDIR="home"
TERMUX__CACHE_SUBDIR="cache"
TERMUX__ROOTFS="${TERMUX_APP__DATA_DIR}/files"
TERMUX__PREFIX="${TERMUX__ROOTFS}/${TERMUX__PREFIX_SUBDIR}"
TERMUX__HOME="${TERMUX__ROOTFS}/${TERMUX__HOME_SUBDIR}"
TERMUX__CACHE_DIR="${TERMUX_APP__DATA_DIR}/${TERMUX__CACHE_SUBDIR}"
TERMUX_DOCKER__ROOTFS="$(pwd)/termux-docker-rootfs"
TERMUX_DOCKER__TMPDIR="$(mktemp -d "/tmp/termux-docker-tmp.XXXXXXXX")"
TERMUX_DOCKER__PKGDIR="${TERMUX_DOCKER__TMPDIR}/packages-${TERMUX_ARCH}"
unset TERMUX_DOCKER__DEPENDS_ARRAY
IFS=, read -a TERMUX_DOCKER__DEPENDS_ARRAY <<< "${TERMUX_DOCKER__DEPENDS// /}"
unset PACKAGE_METADATA
unset PACKAGE_URLS
declare -A PACKAGE_METADATA
declare -A PACKAGE_URLS

# Check for some important utilities that may not be available for
# some reason.
for cmd in ar awk curl grep gzip find sed tar xargs xz zip jq; do
	if [ -z "$(command -v $cmd)" ]; then
		echo "[!] Utility '$cmd' is not available in PATH."
		exit 1
	fi
done

# read_package_lists and pull_package are based on their implementations
# in https://github.com/termux/termux-packages/blob/7a95ee9c2d0ee05e370d1cf951d9f75b4aef8677/scripts/generate-bootstraps.sh

# Download package lists from remote repository.
# Actually, there 2 lists can be downloaded: one architecture-independent and
# one for architecture specified as '$1' argument. That depends on repository.
# If repository has been created using "aptly", then architecture-independent
# list is not available.
read_package_lists_apt() {
	local architecture
	for architecture in all "${TERMUX_ARCH}"; do
		for repository in "${!REPO_BASE_URLS[@]}"; do
			REPO_BASE_URL="${REPO_BASE_URLS[${repository}]}"
			if [ ! -e "${TERMUX_DOCKER__TMPDIR}/${repository}-packages.${architecture}" ]; then
				echo "[*] Downloading ${repository} package list for architecture '${architecture}'..."
				if ! curl --fail --location \
					--output "${TERMUX_DOCKER__TMPDIR}/${repository}-packages.${architecture}" \
					"${REPO_BASE_URL}/binary-${architecture}/Packages"; then
					if [ "$architecture" = "all" ]; then
						echo "[!] Skipping architecture-independent package list as not available..."
						continue
					fi
				fi
				echo >> "${TERMUX_DOCKER__TMPDIR}/${repository}-packages.${architecture}"
			fi

			echo "[*] Reading ${repository} package list for '${architecture}'..."
			while read -r -d $'\xFF' package; do
				if [ -n "$package" ]; then
					local package_name
					package_name=$(echo "$package" | grep -i "^Package:" | awk '{ print $2 }')
					package_url="$(dirname "$(dirname "$(dirname "${REPO_BASE_URL}")")")"/"$(echo "${package}" | \
						grep -i "^Filename:" | awk '{ print $2 }')"

					if [ -z "${PACKAGE_METADATA["$package_name"]-}" ]; then
						PACKAGE_METADATA["$package_name"]="$package"
						PACKAGE_URLS["$package_name"]="$package_url"
					else
						local prev_package_ver cur_package_ver
						cur_package_ver=$(echo "$package" | grep -i "^Version:" | awk '{ print $2 }')
						prev_package_ver=$(echo "${PACKAGE_METADATA["$package_name"]}" | grep -i "^Version:" | awk '{ print $2 }')

						# If package has multiple versions, make sure that our metadata
						# contains the latest one.
						if [ "$(echo -e "${prev_package_ver}\n${cur_package_ver}" | sort -rV | head -n1)" = "${cur_package_ver}" ]; then
							PACKAGE_METADATA["$package_name"]="$package"
							PACKAGE_URLS["$package_name"]="$package_url"
						fi
					fi
				fi
			done < <(sed -e "s/^$/\xFF/g" "${TERMUX_DOCKER__TMPDIR}/${repository}-packages.${architecture}")
		done
	done
}

# Download specified package, its dependencies and then extract *.deb files to the root
pull_package_apt() {
	local package_name=$1
	local package_url="${PACKAGE_URLS[${package_name}]}"
	local package_tmpdir="${TERMUX_DOCKER__PKGDIR}/${package_name}"
	mkdir -p "$package_tmpdir"

	local package_dependencies
	package_dependencies=$(
		while read -r token; do
			echo "$token" | cut -d'|' -f1 | sed -E 's@\(.*\)@@'
		done < <(echo "${PACKAGE_METADATA[${package_name}]}" | grep -i "^Depends:" | sed -E 's@^[Dd]epends:@@' | tr ',' '\n')
	)

	# Recursively handle dependencies.
	if [ -n "$package_dependencies" ]; then
		local dep
		for dep in $package_dependencies; do
			if [ ! -e "${TERMUX_DOCKER__PKGDIR}/${dep}" ]; then
				pull_package_apt "$dep"
			fi
		done
		unset dep
	fi

	if [ ! -e "$package_tmpdir/package.deb" ]; then
		echo "[*] Downloading '$package_name'..."
		curl --fail --location --output "$package_tmpdir/package.deb" "$package_url"

		echo "[*] Extracting '$package_name'..."
		(cd "$package_tmpdir"
			ar x package.deb

			# data.tar may have extension different from .xz
			if [ -f "./data.tar.xz" ]; then
				data_archive="data.tar.xz"
			elif [ -f "./data.tar.gz" ]; then
				data_archive="data.tar.gz"
			else
				echo "No data.tar.* found in '$package_name'."
				exit 1
			fi

			# Do same for control.tar.
			if [ -f "./control.tar.xz" ]; then
				control_archive="control.tar.xz"
			elif [ -f "./control.tar.gz" ]; then
				control_archive="control.tar.gz"
			else
				echo "No control.tar.* found in '$package_name'."
				exit 1
			fi

			# Extract files.
			tar xf "$data_archive" -C "$TERMUX_DOCKER__ROOTFS"

			# Register extracted files.
			tar tf "$data_archive" | sed -E -e 's@^\./@/@' -e 's@^/$@/.@' -e 's@^([^./])@/\1@' > "${TERMUX_DOCKER__ROOTFS}${TERMUX__PREFIX}/var/lib/dpkg/info/${package_name}.list"

			# Generate checksums (md5).
			tar xf "$data_archive"
			find data -type f -print0 | xargs -0 -r md5sum | sed 's@^\.$@@g' > "${TERMUX_DOCKER__ROOTFS}${TERMUX__PREFIX}/var/lib/dpkg/info/${package_name}.md5sums"

			# Extract metadata.
			tar xf "$control_archive"
			{
				cat control
				echo "Status: install ok installed"
				echo
			} >> "${TERMUX_DOCKER__ROOTFS}${TERMUX__PREFIX}/var/lib/dpkg/status"

			# Additional data: conffiles & scripts
			for file in conffiles postinst postrm preinst prerm; do
				if [ -f "${PWD}/${file}" ]; then
					cp "$file" "${TERMUX_DOCKER__ROOTFS}${TERMUX__PREFIX}/var/lib/dpkg/info/${package_name}.${file}"
				fi
			done
		)
	fi
}

read_package_lists_pacman() {
	local repository
	for repository in "${!REPO_BASE_URLS[@]}"; do
		REPO_BASE_URL="${REPO_BASE_URLS[${repository}]}"
		PATH_DB_PACKAGES="${TERMUX_DOCKER__TMPDIR}/${repository}_${TERMUX_ARCH}.json"
		if [ ! -e "${PATH_DB_PACKAGES}" ]; then
			echo "[*] Downloading ${repository} package list for architecture '${TERMUX_ARCH}'..."
			curl --fail --location \
				--output "${PATH_DB_PACKAGES}" \
				"${REPO_BASE_URL}/${TERMUX_ARCH}/${repository}.json"
		fi
	done
}

read_db_packages_pacman() {
	jq -r '."'${package_name}'"."'${1}'" | if type == "array" then .[] else . end' "${PATH_DB_PACKAGES}"
}

print_desc_package_pacman() {
	echo -e "%${1}%\n${2}\n"
}

# Download specified package, its dependencies and then extract *.pkg.tar.xz files to the root
pull_package_pacman() {
	local package_name="$1"	local package_filename="" local package_url="" repository
	for repository in "${!REPO_BASE_URLS[@]}"; do
		REPO_BASE_URL="${REPO_BASE_URLS[${repository}]}"
		PATH_DB_PACKAGES="${TERMUX_DOCKER__TMPDIR}/${repository}_${TERMUX_ARCH}.json"
		local package_filename=$(read_db_packages_pacman "FILENAME")
		package_url="${REPO_BASE_URL}/${TERMUX_ARCH}/${package_filename}"
		if curl -sSf "${package_url}" >/dev/null 2>&1; then
			break
		fi
	done
	local package_tmpdir="${TERMUX_DOCKER__PKGDIR}/${package_name}"
	mkdir -p "$package_tmpdir"

	local package_dependencies=$(read_db_packages_pacman "DEPENDS" | sed 's/<.*$//g; s/>.*$//g; s/=.*$//g')

	if [ "$package_dependencies" != "null" ]; then
		local dep
		for dep in $package_dependencies; do
			if [ ! -e "${TERMUX_DOCKER__PKGDIR}/${dep}" ]; then
				pull_package_pacman "$dep"
			fi
		done
		unset dep
	fi

	if [ ! -e "$package_tmpdir/package.pkg.tar.xz" ]; then
		echo "[*] Downloading '$package_name'..."
		curl --fail --location --output "$package_tmpdir/package.pkg.tar.xz" "${package_url}"

		echo "[*] Extracting '$package_name'..."
		(cd "$package_tmpdir"
			local package_desc="${package_name}-$(read_db_packages_pacman VERSION)"
			mkdir -p "${TERMUX_DOCKER__ROOTFS}${TERMUX__PREFIX}/var/lib/pacman/local/${package_desc}"
			{
				echo "%FILES%"
				tar xvf package.pkg.tar.xz -C "$TERMUX_DOCKER__ROOTFS" .INSTALL .MTREE data 2> /dev/null | grep '^data/' || true
			} >> "${TERMUX_DOCKER__ROOTFS}${TERMUX__PREFIX}/var/lib/pacman/local/${package_desc}/files"
			mv "${TERMUX_DOCKER__ROOTFS}/.MTREE" "${TERMUX_DOCKER__ROOTFS}${TERMUX__PREFIX}/var/lib/pacman/local/${package_desc}/mtree"
			if [ -f "${TERMUX_DOCKER__ROOTFS}/.INSTALL" ]; then
				mv "${TERMUX_DOCKER__ROOTFS}/.INSTALL" "${TERMUX_DOCKER__ROOTFS}${TERMUX__PREFIX}/var/lib/pacman/local/${package_desc}/install"
			fi
			{
				local keys_desc="VERSION BASE DESC URL ARCH BUILDDATE PACKAGER ISIZE GROUPS LICENSE REPLACES DEPENDS OPTDEPENDS CONFLICTS PROVIDES"
				for i in "NAME ${package_name}" \
					"INSTALLDATE $(date +%s)" \
					"VALIDATION $(test $(read_db_packages_pacman PGPSIG) != 'null' && echo 'pgp' || echo 'sha256')"; do
					print_desc_package_pacman ${i}
				done
				jq -r -j '."'${package_name}'" | to_entries | .[] | select(.key | contains('$(sed 's/^/"/; s/ /","/g; s/$/"/' <<< ${keys_desc})')) | "%",(if .key == "ISIZE" then "SIZE" else .key end),"%\n",.value,"\n\n" | if type == "array" then (.| join("\n")) else . end' \
					"${PATH_DB_PACKAGES}"
			} >> "${TERMUX_DOCKER__ROOTFS}${TERMUX__PREFIX}/var/lib/pacman/local/${package_desc}/desc"
		)
	fi
}

echo "[*] Regenerating rootfs..."
rm -rf "${TERMUX_DOCKER__ROOTFS}"
mkdir -p "${TERMUX_DOCKER__ROOTFS}"

echo "[*] Downloading bootstrap..."
curl --fail --location --output "${TERMUX_DOCKER__TMPDIR}/bootstrap-${TERMUX_ARCH}.zip" "${TERMUX_DOCKER__BOOTSTRAP_SRCURL}"
mkdir -p "${TERMUX_DOCKER__ROOTFS}${TERMUX__PREFIX}" \
	"${TERMUX_DOCKER__ROOTFS}${TERMUX__HOME}" \
	"${TERMUX_DOCKER__ROOTFS}${TERMUX__CACHE_DIR}"

echo "[*] Extracting bootstrap..."
unzip -q -d "${TERMUX_DOCKER__ROOTFS}${TERMUX__PREFIX}" "${TERMUX_DOCKER__TMPDIR}/bootstrap-${TERMUX_ARCH}.zip"
pushd "${TERMUX_DOCKER__ROOTFS}${TERMUX__PREFIX}/"
cat "${TERMUX_DOCKER__ROOTFS}${TERMUX__PREFIX}/SYMLINKS.txt" | while read -r line; do
	dest=$(echo "$line" | awk -F '←' '{ print $1 }');
	link=$(echo "$line" | awk -F '←' '{ print $2 }');
	ln -s "$dest" "$link";
done
popd
rm "${TERMUX_DOCKER__ROOTFS}${TERMUX__PREFIX}/SYMLINKS.txt"

case "${TERMUX_PACKAGE_MANAGER}" in
	apt)
		read_package_lists_apt
		for package in "${TERMUX_DOCKER__DEPENDS_ARRAY[@]}"; do
			pull_package_apt "${package}"
		done
		;;
	pacman)
		read_package_lists_pacman
		for package in "${TERMUX_DOCKER__DEPENDS_ARRAY[@]}"; do
			pull_package_pacman "${package}"
		done
		;;
esac

echo '[*] Linking /system to $PREFIX/opt/aosp...'
ln -s "data/data/${TERMUX_APP__PACKAGE_NAME}/files/usr/opt/aosp" "${TERMUX_DOCKER__ROOTFS}/system"

# /etc itself must be a folder, not a symbolic link, because when docker runs the container,
# it overwrites the folder itself, and some files like hostname and hosts,
# but not the passwd or group files inside.
echo '[*] Creating /etc for Docker to place hostname and hosts files into...'
mkdir -p "${TERMUX_DOCKER__ROOTFS}/etc"

echo '[*] Linking /etc/group to /system/etc/group for "USER system" to work in Dockerfiles...'
ln -s /system/etc/group "${TERMUX_DOCKER__ROOTFS}/etc/group"

echo '[*] Linking /etc/passwd to /system/etc/passwd for "docker exec -itu system" to work in shells...'
ln -s /system/etc/passwd "${TERMUX_DOCKER__ROOTFS}/etc/passwd"

echo "[*] Creating /system/etc/group..."
cat << 'EOF' > "${TERMUX_DOCKER__ROOTFS}/system/etc/group"
root:x:0:
system:!:1000:system
EOF

echo "[*] Creating /system/etc/hosts..."
cat << 'EOF' > "${TERMUX_DOCKER__ROOTFS}/system/etc/hosts"
127.0.0.1 localhost
::1 ip6-localhost
EOF

echo "[*] Creating /system/etc/passwd..."
cat << EOF > "${TERMUX_DOCKER__ROOTFS}/system/etc/passwd"
root:x:0:0:root:/:/system/bin/sh
system:x:1000:1000:system:${TERMUX__ROOTFS}/home:${TERMUX__PREFIX}/bin/login
EOF

echo "[*] Copying entrypoint.sh to /..."
cp entrypoint.sh "${TERMUX_DOCKER__ROOTFS}/"

echo "[*] Copying entrypoint_root.sh to /..."
cp entrypoint_root.sh "${TERMUX_DOCKER__ROOTFS}/"

echo "[*] Setting permissions..."
find -L "${TERMUX_DOCKER__ROOTFS}/data" \
	-type d -exec \
	chmod 755 "{}" \;
find -L "${TERMUX_DOCKER__ROOTFS}${TERMUX__ROOTFS}" \
	-type f -o -type d -exec \
	chmod g-rwx,o-rwx "{}" \;
find -L "${TERMUX_DOCKER__ROOTFS}${TERMUX__PREFIX}/bin" \
	"${TERMUX_DOCKER__ROOTFS}${TERMUX__PREFIX}/libexec" \
	-type f -exec \
	chmod 700 "{}" \;
if [ "${TERMUX_PACKAGE_MANAGER}" = "apt" ]; then
	find -L "${TERMUX_DOCKER__ROOTFS}${TERMUX__PREFIX}/lib/apt" \
		-type f -exec \
		chmod 700 "{}" \;
fi
find -L "${TERMUX_DOCKER__ROOTFS}/system" \
	-type f -executable -exec \
	chmod 755 "{}" \;
find -L "${TERMUX_DOCKER__ROOTFS}/system" \
	-type f ! -executable -exec \
	chmod 644 "{}" \;

echo "[*] Rootfs generation complete. Building Docker image..."
$SUDO $OCI ${OCI_ARG} \
	--no-cache \
	-t "${TERMUX_DOCKER__IMAGE_NAME}:${TERMUX_ARCH}" \
	${PLATFORM_ARG} \
	--build-arg TERMUX_DOCKER__ROOTFS="$(basename "${TERMUX_DOCKER__ROOTFS}")" \
	--build-arg TERMUX__PREFIX="${TERMUX__PREFIX}" \
	--build-arg TERMUX__HOME="${TERMUX__HOME}" \
	--build-arg TERMUX__CACHE_DIR="${TERMUX__CACHE_DIR}" \
	.

if [ "${1-}" = "publish" ]; then
	$SUDO $OCI push "${TERMUX_DOCKER__IMAGE_NAME}:${TERMUX_ARCH}"
fi

if [ "${TERMUX_ARCH}" = "x86_64" ]; then
	$SUDO $OCI tag "${TERMUX_DOCKER__IMAGE_NAME}:${TERMUX_ARCH}" "${TERMUX_DOCKER__IMAGE_NAME}:latest"
	if [ "${1-}" = "publish" ]; then
		$SUDO $OCI push "${TERMUX_DOCKER__IMAGE_NAME}:latest"
	fi
fi
