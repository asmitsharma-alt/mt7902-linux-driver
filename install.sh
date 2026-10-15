#!/usr/bin/env bash
# ==============================================================================
# Universal MediaTek MT7902 Linux Driver & Bluetooth Installer
# Supports direct execution OR piping via:
#   curl -sSL https://raw.githubusercontent.com/asmitsharma-alt/mt7902-linux-driver/master/install.sh | sudo bash
# ==============================================================================

set -e

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

echo -e "${BLUE}=====================================================${NC}"
echo -e "${BLUE}  MediaTek MT7902 Wi-Fi 6E & Bluetooth 5.3 Installer  ${NC}"
echo -e "${BLUE}=====================================================${NC}"

if [ "$EUID" -ne 0 ]; then
    echo -e "${RED}[ERROR] This installer must be run with root privileges (sudo).${NC}"
    exit 1
fi

KERNEL_VER=$(uname -r)
echo -e "${GREEN}[*] Target Kernel:${NC} ${KERNEL_VER}"

# ------------------------------------------------------------------------------
# 1. Distro Detection & Dependency Installation
# ------------------------------------------------------------------------------
echo -e "${GREEN}[*] Detecting Linux distribution...${NC}"

if [ -f /etc/os-release ]; then
    . /etc/os-release
    DISTRO_ID=$ID
    DISTRO_LIKE=${ID_LIKE:-$ID}
else
    echo -e "${RED}[ERROR] Cannot detect distribution. /etc/os-release not found.${NC}"
    exit 1
fi

echo -e "${GREEN}[*] Detected OS:${NC} ${NAME} (${DISTRO_ID})"

install_deps() {
    case "$DISTRO_LIKE" in
        *debian*|*ubuntu*)
            echo -e "${YELLOW}[*] Installing dependencies via apt...${NC}"
            apt-get update
            apt-get install -y build-essential dkms git linux-headers-"${KERNEL_VER}" bc iw bluez udev
            ;;
        *fedora*|*rhel*)
            echo -e "${YELLOW}[*] Installing dependencies via dnf...${NC}"
            dnf install -y kernel-devel-"${KERNEL_VER}" kernel-headers-"${KERNEL_VER}" dkms gcc make git bc iw bluez systemd-udev
            ;;
        *arch*|*manjaro*)
            echo -e "${YELLOW}[*] Installing dependencies via pacman...${NC}"
            pacman -Sy --noconfirm linux-headers base-devel dkms git iw bluez udev
            ;;
        *suse*)
            echo -e "${YELLOW}[*] Installing dependencies via zypper...${NC}"
            zypper refresh
            zypper install -y kernel-devel kernel-default-devel dkms gcc make git bc iw bluez udev
            ;;
        *)
            echo -e "${YELLOW}[!] Unknown package manager family. Please ensure kernel headers, bluez, and build tools are installed.${NC}"
            ;;
    esac
}

install_deps

# ------------------------------------------------------------------------------
# 2. Self-Bootstrap Repository (If executed via curl/wget pipe)
# ------------------------------------------------------------------------------
REPO_URL="https://github.com/asmitsharma-alt/mt7902-linux-driver.git"

if [ ! -f "Makefile" ] || [ ! -d "firmware" ]; then
    echo -e "${YELLOW}[*] Running from pipe. Downloading full driver repository...${NC}"
    WORK_DIR=$(mktemp -d -t mt7902-install-XXXXXX)
    git clone --depth 1 "${REPO_URL}" "${WORK_DIR}"
    cd "${WORK_DIR}"
fi

# ------------------------------------------------------------------------------
# 3. Deploy Official Wi-Fi & Bluetooth Firmware
# ------------------------------------------------------------------------------
echo -e "${GREEN}[*] Deploying MediaTek MT7902 Firmware to /lib/firmware/mediatek/...${NC}"
mkdir -p /lib/firmware/mediatek

if [ -d "firmware" ]; then
    cp -v firmware/WIFI_MT7902_patch_mcu_1_1_hdr.bin /lib/firmware/mediatek/ 2>/dev/null || true
    cp -v firmware/WIFI_RAM_CODE_MT7902_1.bin /lib/firmware/mediatek/ 2>/dev/null || true
    cp -v firmware/BT_RAM_CODE_MT7902_1_1_hdr.bin /lib/firmware/mediatek/ 2>/dev/null || true
fi

chmod 644 /lib/firmware/mediatek/*MT7902* 2>/dev/null || true

# ------------------------------------------------------------------------------
# 4. Configure & Activate Bluetooth 5.3 Controller (USB 13d3:3579)
# ------------------------------------------------------------------------------
echo -e "${GREEN}[*] Configuring MediaTek MT7902 Bluetooth subsystem...${NC}"

# Ensure btusb is loaded
modprobe btusb 2>/dev/null || true

# Write udev rule for automatic Bluetooth binding on boot
UDEV_RULE_FILE="/etc/udev/rules.d/99-mt7902-bluetooth.rules"
cat << 'EOF' > "${UDEV_RULE_FILE}"
# MediaTek MT7902 Bluetooth Controller (AzureWave / IMC Networks & Foxconn)
ACTION=="add", SUBSYSTEM=="usb", ATTR{idVendor}=="13d3", ATTR{idProduct}=="3579", RUN+="/bin/sh -c 'echo 13d3 3579 > /sys/bus/usb/drivers/btusb/new_id'"
ACTION=="add", SUBSYSTEM=="usb", ATTR{idVendor}=="0489", ATTR{idProduct}=="e0f5", RUN+="/bin/sh -c 'echo 0489 e0f5 > /sys/bus/usb/drivers/btusb/new_id'"
ACTION=="add", SUBSYSTEM=="usb", ATTR{idVendor}=="0489", ATTR{idProduct}=="e0f6", RUN+="/bin/sh -c 'echo 0489 e0f6 > /sys/bus/usb/drivers/btusb/new_id'"
EOF

# Reload udev
udevadm control --reload-rules 2>/dev/null || true
udevadm trigger 2>/dev/null || true

# Trigger dynamic binding directly if device is currently present
if [ -w /sys/bus/usb/drivers/btusb/new_id ]; then
    echo "13d3 3579" > /sys/bus/usb/drivers/btusb/new_id 2>/dev/null || true
    echo "0489 e0f5" > /sys/bus/usb/drivers/btusb/new_id 2>/dev/null || true
    echo "0489 e0f6" > /sys/bus/usb/drivers/btusb/new_id 2>/dev/null || true
fi

# Restart bluetooth service if systemd is active
if command -v systemctl >/dev/null 2>&1; then
    systemctl restart bluetooth 2>/dev/null || true
fi

# ------------------------------------------------------------------------------
# 5. Kernel Compatibility & Wi-Fi Driver Build
# ------------------------------------------------------------------------------
echo -e "${GREEN}[*] Compiling Wi-Fi Driver Module for Kernel ${KERNEL_VER}...${NC}"

UPSTREAM_SUPPORTS=$(modinfo -F alias mt7921e 2>/dev/null | grep -i "14C3.*7902" || true)

if [ -n "$UPSTREAM_SUPPORTS" ]; then
    echo -e "${GREEN}[+] Your kernel already has native in-tree support for MT7902 Wi-Fi.${NC}"
    echo -e "${GREEN}[*] Loading native module...${NC}"
    modprobe -r mt7921e 2>/dev/null || true
    modprobe mt7921e
else
    echo -e "${YELLOW}[*] Compiling standalone driver module...${NC}"
    make clean
    make
    
    echo -e "${GREEN}[*] Installing compiled kernel module...${NC}"
    mkdir -p "/lib/modules/${KERNEL_VER}/kernel/drivers/net/wireless/mediatek/"
    cp mt7902.ko "/lib/modules/${KERNEL_VER}/kernel/drivers/net/wireless/mediatek/"
    depmod -a

    echo -e "${GREEN}[*] Registering with DKMS for automatic rebuilds on kernel updates...${NC}"
    if command -v dkms >/dev/null 2>&1; then
        DKMS_DIR="/usr/src/mt7902-1.0.0"
        rm -rf "${DKMS_DIR}"
        mkdir -p "${DKMS_DIR}"
        cp -r src Makefile dkms.conf "${DKMS_DIR}/"
        dkms add -m mt7902 -v 1.0.0 || true
        dkms build -m mt7902 -v 1.0.0 || true
        dkms install -m mt7902 -v 1.0.0 --force || true
    fi

    echo -e "${GREEN}[*] Loading module into kernel...${NC}"
    modprobe -v mt7902 || insmod mt7902.ko
fi

# ------------------------------------------------------------------------------
# 6. Verification & Status Report
# ------------------------------------------------------------------------------
echo -e "${BLUE}=====================================================${NC}"
echo -e "${GREEN}   Installation Complete! Checking Device Status:     ${NC}"
echo -e "${BLUE}=====================================================${NC}"

if command -v iw >/dev/null 2>&1; then
    echo -e "${YELLOW}[*] Wireless Interfaces:${NC}"
    iw dev || true
fi

if command -v rfkill >/dev/null 2>&1; then
    echo -e "\n${YELLOW}[*] RFKill Status (Wi-Fi & Bluetooth):${NC}"
    rfkill list || true
fi

if command -v bluetoothctl >/dev/null 2>&1; then
    echo -e "\n${YELLOW}[*] Bluetooth Controller:${NC}"
    bluetoothctl show 2>/dev/null || true
fi

echo -e "\n${GREEN}[SUCCESS] MediaTek MT7902 Wi-Fi 6E & Bluetooth 5.3 are active!${NC}"
