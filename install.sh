#!/usr/bin/env bash
# ==============================================================================
# Universal MediaTek MT7902 Linux Driver Installer
# Supports: Ubuntu, Debian, Linux Mint, Fedora, RHEL, CentOS, Arch Linux,
#           Manjaro, openSUSE, CachyOS, Pop!_OS
# ==============================================================================

set -e

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

echo -e "${BLUE}=====================================================${NC}"
echo -e "${BLUE}   MediaTek MT7902 Wi-Fi 6E Linux Driver Installer   ${NC}"
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
            apt-get install -y build-essential dkms git linux-headers-"${KERNEL_VER}" bc iw
            ;;
        *fedora*|*rhel*)
            echo -e "${YELLOW}[*] Installing dependencies via dnf...${NC}"
            dnf install -y kernel-devel-"${KERNEL_VER}" kernel-headers-"${KERNEL_VER}" dkms gcc make git bc iw
            ;;
        *arch*|*manjaro*)
            echo -e "${YELLOW}[*] Installing dependencies via pacman...${NC}"
            pacman -Sy --noconfirm linux-headers base-devel dkms git iw
            ;;
        *suse*)
            echo -e "${YELLOW}[*] Installing dependencies via zypper...${NC}"
            zypper refresh
            zypper install -y kernel-devel kernel-default-devel dkms gcc make git bc iw
            ;;
        *)
            echo -e "${YELLOW}[!] Unknown package manager family. Please ensure kernel headers and build-essential are installed.${NC}"
            ;;
    esac
}

install_deps

# ------------------------------------------------------------------------------
# 2. Deploy Official Firmware
# ------------------------------------------------------------------------------
echo -e "${GREEN}[*] Deploying MediaTek MT7902 Firmware to /lib/firmware/mediatek/...${NC}"
mkdir -p /lib/firmware/mediatek

if [ -d "firmware" ]; then
    cp -v firmware/WIFI_MT7902_patch_mcu_1_1_hdr.bin /lib/firmware/mediatek/ 2>/dev/null || true
    cp -v firmware/WIFI_RAM_CODE_MT7902_1.bin /lib/firmware/mediatek/ 2>/dev/null || true
fi

# Set permissions
chmod 644 /lib/firmware/mediatek/WIFI_*MT7902* 2>/dev/null || true

# ------------------------------------------------------------------------------
# 3. Kernel Compatibility & Driver Build
# ------------------------------------------------------------------------------
echo -e "${GREEN}[*] Compiling Driver Module for Kernel ${KERNEL_VER}...${NC}"

# Check if upstream mt76 has native mt7902 support in this kernel
UPSTREAM_SUPPORTS=$(modinfo -F alias mt7921e 2>/dev/null | grep -i "14C3.*7902" || true)

if [ -n "$UPSTREAM_SUPPORTS" ]; then
    echo -e "${GREEN}[+] Great news! Your kernel already has native in-tree support for MT7902.${NC}"
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
# 4. Verification & Status Report
# ------------------------------------------------------------------------------
echo -e "${BLUE}=====================================================${NC}"
echo -e "${GREEN}   Installation Complete! Checking Wireless Interfaces:${NC}"
echo -e "${BLUE}=====================================================${NC}"

if command -v iw >/dev/null 2>&1; then
    iw dev || true
fi

if command -v ip >/dev/null 2>&1; then
    echo -e "${YELLOW}[*] Network Interfaces:${NC}"
    ip link show | grep -E "wl[a-z0-9]+" || true
fi

echo -e "\n${GREEN}[SUCCESS] Wi-Fi adapter is now initialized!${NC}"
echo -e "You can connect using NetworkManager: ${YELLOW}nmcli device wifi list${NC}"
