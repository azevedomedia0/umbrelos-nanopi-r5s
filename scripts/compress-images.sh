#!/bin/bash
# ==============================================================================
# Compress umbrelOS images for distribution / GitHub Release assets
# ==============================================================================

set -euo pipefail

WORKDIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "${WORKDIR}"

echo ">>> Compressing images for release (using multithreaded xz)..."

if [ -f "umbrelos-2.0.0-nanopi-r5s-sd.img" ] && [ ! -f "umbrelos-2.0.0-nanopi-r5s-sd.img.xz" ]; then
    echo "Compressing umbrelos-2.0.0-nanopi-r5s-sd.img..."
    xz -T0 -k -v -9 "umbrelos-2.0.0-nanopi-r5s-sd.img"
fi

if [ -f "umbrelos-2.0.0-nanopi-r5s-eflasher.img" ] && [ ! -f "umbrelos-2.0.0-nanopi-r5s-eflasher.img.xz" ]; then
    echo "Compressing umbrelos-2.0.0-nanopi-r5s-eflasher.img..."
    xz -T0 -k -v -9 "umbrelos-2.0.0-nanopi-r5s-eflasher.img"
fi

echo ">>> Generating SHA256 checksums..."
sha256sum umbrelos-2.0.0-nanopi-r5s*.img* > SHA256SUMS.txt 2>/dev/null || shasum -a 256 umbrelos-2.0.0-nanopi-r5s*.img* > SHA256SUMS.txt

echo ">>> Done! Generated release files:"
ls -lh umbrelos-2.0.0-nanopi-r5s*.xz SHA256SUMS.txt
