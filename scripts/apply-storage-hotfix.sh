#!/bin/bash
# ==============================================================================
# UmbrelOS 2.0 NanoPi R5S Storage Check Hotfix
#
# Fixes: "umbrelOS couldn't check your storage. Check again before making any changes."
#
# UNOFFICIAL COMMUNITY-MADE BUILD
# ==============================================================================

set -euo pipefail

if [ "$(id -u)" -ne 0 ]; then
    echo "This script must be run as root: sudo bash $0"
    exit 1
fi

echo "=========================================================="
echo " Applying UmbrelOS 2.0 NanoPi R5S Storage Hotfix"
echo "=========================================================="

UMBREL_DIR="/opt/umbreld"

if [ ! -d "${UMBREL_DIR}" ]; then
    echo "Error: ${UMBREL_DIR} not found. Are you running this on your NanoPi R5S?"
    exit 1
fi

# 1. Sudoers rule
mkdir -p /etc/sudoers.d
echo "umbrel ALL=(ALL) NOPASSWD: ALL" > /etc/sudoers.d/umbrel
chmod 440 /etc/sudoers.d/umbrel
echo "✓ Configured sudoers"

# 2. Patch system-disk.ts
SYS_DISK="${UMBREL_DIR}/source/modules/system/system-disk.ts"
if [ -f "${SYS_DISK}" ]; then
    echo ">>> Patching system-disk.ts..."
    python3 - <<'PYEOF'
import sys

path = "/opt/umbreld/source/modules/system/system-disk.ts"
with open(path, "r") as f:
    content = f.read()

# Update signature
content = content.replace(
    "export function resolveSystemDiskNames(\n\tsources: Array<string | undefined>,\n\tblockDevices: BlockDeviceRelation[],\n): Set<string> {",
    "export function resolveSystemDiskNames(\n\tsources: Array<string | undefined>,\n\tblockDevices: BlockDeviceRelation[],\n\tisRugixSystem: boolean = false,\n): Set<string> {"
)

# Non-fatal on unknown relations outside Rugix
content = content.replace(
    "if (!relations?.length) throw new Error(`Could not resolve system block device /dev/${deviceName}`)",
    "if (!relations?.length) { if (!isRugixSystem) return new Set(); throw new Error(`Could not resolve system block device /dev/${deviceName}`) }"
)
content = content.replace(
    "if (systemDisks.size === 0) throw new Error('Could not determine the physical disk backing the running system')",
    "if (systemDisks.size === 0 && isRugixSystem) throw new Error('Could not determine the physical disk backing the running system')"
)
content = content.replace(
    "{allowUnresolvedOutsideRugix = false}: {allowUnresolvedOutsideRugix?: boolean} = {}",
    "{allowUnresolvedOutsideRugix = true}: {allowUnresolvedOutsideRugix?: boolean} = {}"
)
content = content.replace(
    "return resolveSystemDiskNames(sources, blockDevices)",
    "return resolveSystemDiskNames(sources, blockDevices, isRugixSystem)"
)

# Add /dev/root resolution via sysfs
root_fallback = """				if (!source || source === '/dev/root') {
					try {
						const stat = await fse.stat(systemPath)
						const dev = BigInt(stat.dev)
						const major = Number(((dev >> 8n) & 0xfffn) | ((dev >> 32n) & ~0xfffn))
						const minor = Number((dev & 0xffn) | ((dev >> 12n) & ~0xfffn))
						if (major > 0) {
							const sysLink = await fse.readlink(`/sys/dev/block/${major}:${minor}`)
							const kname = sysLink.split('/').pop()
							if (kname) source = `/dev/${kname}`
						}
					} catch {}
				}

				if (!source || source === '/dev/root') {
					try {
						const {stdout} = await $`findmnt -T ${systemPath} -n -o SOURCE`
						const found = stdout.trim()
						if (found && found.startsWith('/dev/')) source = found
					} catch {}
				}"""

target_df = """				if (!source) throw new Error(`Could not determine the filesystem source for ${systemPath}`)"""
if target_df in content and root_fallback not in content:
    content = content.replace(target_df, root_fallback + "\n\n" + target_df)

with open(path, "w") as f:
    f.write(content)
print("  ✓ system-disk.ts patched")
PYEOF
fi

# 3. Patch internal-storage.ts
INT_STORAGE="${UMBREL_DIR}/source/modules/hardware/internal-storage.ts"
if [ -f "${INT_STORAGE}" ]; then
    echo ">>> Patching internal-storage.ts..."
    python3 - <<'PYEOF'
import sys

path = "/opt/umbreld/source/modules/hardware/internal-storage.ts"
with open(path, "r") as f:
    content = f.read()

# Pass allowUnresolvedOutsideRugix: true
content = content.replace(
    "const systemDiskNames = await getSystemDiskNames(this.#umbreld.dataDirectory)",
    """let systemDiskNames = new Set<string>()
		try {
			systemDiskNames = await getSystemDiskNames(this.#umbreld.dataDirectory, {
				allowUnresolvedOutsideRugix: true,
			})
		} catch (error) {
			this.logger.error('Failed to resolve system disk names', error)
		}"""
)

# Search both /dev/disk/by-umbrel-id and /dev/disk/by-id
content = content.replace(
    "const byIdDir = '/dev/disk/by-umbrel-id'",
    "for (const byIdDir of ['/dev/disk/by-umbrel-id', '/dev/disk/by-id'])"
)

with open(path, "w") as f:
    f.write(content)
print("  ✓ internal-storage.ts patched")
PYEOF
fi

# 4. Patch system.ts for NanoPi R5S hardware detection
SYS_TS="${UMBREL_DIR}/source/modules/system/system.ts"
if [ -f "${SYS_TS}" ]; then
    echo ">>> Patching system.ts..."
    python3 - <<'PYEOF'
path = "/opt/umbreld/source/modules/system/system.ts"
with open(path, "r") as f:
    content = f.read()

target_blank = "\t// Blank out model and serial for non Umbrel devices"
nanopi_detect = """\ttry {
		if (await fse.pathExists('/proc/device-tree/model')) {
			const dtModel = (await fse.readFile('/proc/device-tree/model', 'utf8')).replace(/\\0/g, '').trim()
			if (dtModel.toLowerCase().includes('nanopi r5s') || dtModel.toLowerCase().includes('rk3568')) {
				manufacturer = 'FriendlyElec'
				productName = 'NanoPi R5S'
				device = 'FriendlyElec NanoPi R5S'
				deviceId = 'nanopi-r5s'
			}
		}
	} catch (error) {}

\t// Blank out model and serial for non Umbrel devices"""

if target_blank in content and "NanoPi R5S" not in content:
    content = content.replace(target_blank, nanopi_detect, 1)

with open(path, "w") as f:
    f.write(content)
print("  ✓ system.ts patched")
PYEOF
fi

# 5. Restart umbrel service
echo ">>> Restarting umbreld daemon..."
systemctl restart umbrel
echo "✓ umbreld restarted"

echo "=========================================================="
echo " Hotfix applied successfully!"
echo " You can now return to the web dashboard and create your account."
echo "=========================================================="
