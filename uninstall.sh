#!/usr/bin/env bash
# ==============================================================================
# Uninstaller for MediaTek MT7902 Linux Driver
# ==============================================================================

set -e

if [ "$EUID" -ne 0 ]; then
    echo "Please run as root (sudo)."
    exit 1
fi

echo "Removing MT7902 driver..."

# Unload module
modprobe -r mt7902 2>/dev/null || true

# Remove from DKMS
if command -v dkms >/dev/null 2>&1; then
    dkms remove -m mt7902 -v 1.0.0 --all 2>/dev/null || true
    rm -rf /usr/src/mt7902-1.0.0
fi

# Remove module binary
rm -f /lib/modules/$(uname -r)/kernel/drivers/net/wireless/mediatek/mt7902.ko
depmod -a

echo "Driver uninstalled successfully."
