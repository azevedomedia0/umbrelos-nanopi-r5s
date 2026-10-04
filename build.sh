#!/bin/bash
# ==============================================================================
# umbrelOS 2.0 Builder for FriendlyElec NanoPi R5S (RK3568)
#
# UNOFFICIAL COMMUNITY-MADE BUILD
# Not affiliated with or endorsed by Umbrel, Inc.
# ==============================================================================

set -euo pipefail

if [ "$(id -u)" -ne 0 ]; then
    echo "This script must be run as root or with sudo."
    exit 1
fi

WORKDIR="$(pwd)"
BUILD_DIR="${WORKDIR}/build"
ROOTFS_DIR="${BUILD_DIR}/rootfs"
TARGET_OS_DIR="${BUILD_DIR}/umbrelos-arm64"
OUT_DIR="${WORKDIR}/out"

UMBREL_VERSION="2.0.0"
ROCKCHIP_SOC="rk3568"

echo "=========================================================="
echo " Building umbrelOS ${UMBREL_VERSION} for NanoPi R5S (${ROCKCHIP_SOC})"
echo " UNOFFICIAL COMMUNITY-MADE BUILD"
echo "=========================================================="

mkdir -p "${BUILD_DIR}" "${OUT_DIR}"

# 1. Check prerequisites
for cmd in git rsync mke2fs simg2img img2simg parted losetup curl unzip; do
    if ! command -v "$cmd" >/dev/null 2>&1; then
        echo "Missing required tool: $cmd"
        echo "Please install: apt-get install -y git rsync e2fsprogs android-sdk-libsparse-utils parted curl unzip"
        exit 1
    fi
done

# 2. Clone sd-fuse_rk3568 if not present
if [ ! -d "${BUILD_DIR}/sd-fuse_rk3568" ]; then
    echo ">>> Cloning friendlyarm/sd-fuse_rk3568..."
    git clone --depth 1 -b kernel-6.1.y https://github.com/friendlyarm/sd-fuse_rk3568.git "${BUILD_DIR}/sd-fuse_rk3568"
fi

# 3. Download official umbrelOS 2.0 Pi image if not present
UMBREL_IMG="${WORKDIR}/umbrelos-pi.img"
if [ ! -f "${UMBREL_IMG}" ]; then
    echo ">>> Downloading official umbrelOS ${UMBREL_VERSION}..."
    curl -L -o "${WORKDIR}/umbrelos-pi.img.zip" "https://download.umbrel.com/release/${UMBREL_VERSION}/umbrelos-pi.img.zip"
    unzip "${WORKDIR}/umbrelos-pi.img.zip" -d "${WORKDIR}"
    rm -f "${WORKDIR}/umbrelos-pi.img.zip"
fi

echo ">>> Mounting umbrelOS 2.0 image..."
LOOP_UMBREL=$(losetup -Pf --show "${UMBREL_IMG}")
MOUNT_UMBREL="${BUILD_DIR}/mnt_umbrel"
mkdir -p "${MOUNT_UMBREL}"
mount -o ro "${LOOP_UMBREL}p4" "${MOUNT_UMBREL}"

# 4. Rsync rootfs
echo ">>> Staging rootfs..."
rm -rf "${ROOTFS_DIR}"
mkdir -p "${ROOTFS_DIR}"
rsync -aHAX --numeric-ids \
    --exclude='/boot/vmlinuz*' \
    --exclude='/boot/initrd*' \
    --exclude='/boot/System.map*' \
    --exclude='/boot/config*' \
    --exclude='/lib/modules/6.18*' \
    "${MOUNT_UMBREL}/" "${ROOTFS_DIR}/"

umount "${MOUNT_UMBREL}"
losetup -d "${LOOP_UMBREL}"
rmdir "${MOUNT_UMBREL}"

# 5. Populate user and directories
echo ">>> Configuring directories, user accounts, and permissions..."
mkdir -p "${ROOTFS_DIR}/home/umbrel" "${ROOTFS_DIR}/data/umbrel-os/home/umbrel"
chown -R 1000:1000 "${ROOTFS_DIR}/home/umbrel" "${ROOTFS_DIR}/data/umbrel-os/home/umbrel"

mkdir -p "${ROOTFS_DIR}/var/log" "${ROOTFS_DIR}/data/umbrel-os/var/log"
mkdir -p "${ROOTFS_DIR}/data/umbrel-os/var/lib/docker" "${ROOTFS_DIR}/var/lib/docker"
mkdir -p "${ROOTFS_DIR}/data/umbrel-os/var/lib/systemd/timesync" "${ROOTFS_DIR}/var/lib/systemd/timesync"
mkdir -p "${ROOTFS_DIR}/data/umbrel-os/kopia" "${ROOTFS_DIR}/kopia"
mkdir -p "${ROOTFS_DIR}/data/ssh"
chmod 700 "${ROOTFS_DIR}/data/ssh"

# Ensure docker group includes umbrel
sed -i "s/^docker:x:987:.*$/docker:x:987:umbrel/" "${ROOTFS_DIR}/etc/group" || true

# 6. Configure hostname and hosts
echo "umbrel" > "${ROOTFS_DIR}/etc/hostname"
cat > "${ROOTFS_DIR}/etc/hosts" <<'EOF'
127.0.0.1 localhost
127.0.1.1 umbrel
::1 localhost ip6-localhost ip6-loopback
ff02::1 ip6-allnodes
ff02::2 ip6-allrouters
EOF

# 7. Configure /etc/fstab
cat > "${ROOTFS_DIR}/etc/fstab" <<'EOF'
# /etc/fstab: static file system information.
LABEL=rootfs    /                                           ext4    errors=remount-ro,noatime,discard 0 1
/data/umbrel-os/var/log                     /var/log                     none    bind        0       0
/data/umbrel-os/var/lib/docker              /var/lib/docker              none    bind        0       0
/data/umbrel-os/home                        /home                        none    bind        0       0
/data/umbrel-os/var/lib/systemd/timesync    /var/lib/systemd/timesync    none    bind        0       0
/data/umbrel-os/kopia                       /kopia                       none    bind        0       0
EOF

# 8. Reset machine-id
truncate -s 0 "${ROOTFS_DIR}/etc/machine-id"
rm -f "${ROOTFS_DIR}/var/lib/dbus/machine-id"
ln -sf /etc/machine-id "${ROOTFS_DIR}/var/lib/dbus/machine-id"

# 9. Update issue
echo "UmbrelOS 2.0 (NanoPi R5S) \n \l" > "${ROOTFS_DIR}/etc/issue"
echo "UmbrelOS 2.0 (NanoPi R5S)" > "${ROOTFS_DIR}/etc/issue.net"

# 10. Build sparse rootfs.img
echo ">>> Building Android sparse rootfs.img..."
mkdir -p "${TARGET_OS_DIR}"
MKE2FS="${BUILD_DIR}/sd-fuse_rk3568/tools/aarch64/mke2fs"
[ ! -f "${MKE2FS}" ] && MKE2FS="mke2fs"

MKE2FS_CONFIG="${BUILD_DIR}/sd-fuse_rk3568/tools/mke2fs.conf" \
"${MKE2FS}" -N 300000 -E android_sparse -t ext4 -L rootfs -M /root -b 4096 \
    -d "${ROOTFS_DIR}" "${TARGET_OS_DIR}/rootfs.img" 1572864

# 11. Generate parameter.txt
cd "${BUILD_DIR}/sd-fuse_rk3568"
ln -sfn "${TARGET_OS_DIR}" umbrelos-arm64
./tools/generate-partmap-txt.sh 6442450944 umbrelos-arm64

# 12. Create bootable SD image
echo ">>> Generating bootable SD image..."
RAW_SIZE_MB=8192 ./mk-sd-image.sh umbrelos-arm64
cp -f "${BUILD_DIR}/sd-fuse_rk3568/out/"*sd* "${OUT_DIR}/umbrelos-2.0.0-nanopi-r5s-sd.img"

echo "=========================================================="
echo " Build completed successfully!"
echo " Image output: ${OUT_DIR}/umbrelos-2.0.0-nanopi-r5s-sd.img"
echo "=========================================================="
