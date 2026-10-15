# MediaTek MT7902 Wi-Fi 6E Linux Driver

[![Kernel](https://img.shields.io/badge/Linux%20Kernel-5.15%20--%207.x%2B-blue.svg)](https://kernel.org)
[![DKMS](https://img.shields.io/badge/DKMS-Supported-brightgreen.svg)](https://github.com/dell/dkms)
[![License: GPL v2](https://img.shields.io/badge/License-GPL%20v2-blue.svg)](https://www.gnu.org/licenses/old-licenses/gpl-2.0.en.html)

Standalone Linux kernel driver and DKMS package for the **MediaTek MT7902 Wireless LAN Card (Wi-Fi 6E 802.11ax + Bluetooth 5.3)**.

---

## 📌 Hardware Overview

| Specification | Value |
| :--- | :--- |
| **Device Model** | MediaTek Wi-Fi 6E MT7902 Wireless LAN Card |
| **Wi-Fi Hardware ID (PCIe)** | `PCI\VEN_14C3&DEV_7902` (`14c3:7902`) |
| **Bluetooth Hardware ID (USB)** | `USB\VID_13D3&PID_3579` / `0489:e0f5` (Bluetooth 5.3) |
| **Wi-Fi Bands** | 2.4 GHz, 5 GHz, 6 GHz (Wi-Fi 6E) |
| **Channel Widths** | 20 MHz, 40 MHz, 80 MHz, 160 MHz |
| **Wi-Fi Standards** | 802.11a/b/g/n/ac/ax |
| **Included Firmware** | `WIFI_MT7902_patch_mcu_1_1_hdr.bin`<br>`WIFI_RAM_CODE_MT7902_1.bin`<br>`BT_RAM_CODE_MT7902_1_1_hdr.bin` |

---

## 🚀 Quick 1-Command Install (Any Linux Distro)

Paste this single command into your Linux terminal:

```bash
curl -sSL https://raw.githubusercontent.com/asmitsharma-alt/mt7902-linux-driver/master/install.sh | sudo bash
```

*Or using `wget`:*

```bash
wget -qO- https://raw.githubusercontent.com/asmitsharma-alt/mt7902-linux-driver/master/install.sh | sudo bash
```

*Or by cloning:*

```bash
git clone https://github.com/asmitsharma-alt/mt7902-linux-driver.git && cd mt7902-linux-driver && sudo ./install.sh
```

---

## 📦 Distribution-by-Distribution Guide

### 1. Ubuntu / Debian / Linux Mint / Pop!_OS
```bash
# 1. Install build tools and kernel headers
sudo apt update
sudo apt install -y build-essential dkms git linux-headers-$(uname -r) bc iw

# 2. Clone and install
git clone https://github.com/asmitsharma-alt/mt7902-linux-driver.git
cd mt7902-linux-driver
sudo ./install.sh
```

### 2. Fedora / Red Hat Enterprise Linux / Rocky Linux
```bash
# 1. Install development tools
sudo dnf install -y kernel-devel-$(uname -r) kernel-headers-$(uname -r) dkms gcc make git bc iw

# 2. Clone and install
git clone https://github.com/asmitsharma-alt/mt7902-linux-driver.git
cd mt7902-linux-driver
sudo ./install.sh
```

### 3. Arch Linux / Manjaro / CachyOS / EndeavourOS
```bash
# 1. Install prerequisites
sudo pacman -Sy --noconfirm linux-headers base-devel dkms git iw

# 2. Clone and install
git clone https://github.com/asmitsharma-alt/mt7902-linux-driver.git
cd mt7902-linux-driver
sudo ./install.sh
```

### 4. openSUSE (Tumbleweed / Leap)
```bash
# 1. Install prerequisites
sudo zypper install -y kernel-devel kernel-default-devel dkms gcc make git bc iw

# 2. Clone and install
git clone https://github.com/asmitsharma-alt/mt7902-linux-driver.git
cd mt7902-linux-driver
sudo ./install.sh
```

---

## 🔒 Secure Boot (If Enabled)

If your machine has **UEFI Secure Boot** enabled in BIOS, third-party kernel modules will be blocked by the kernel unless signed with a Machine Owner Key (MOK):

1. Generate a signing key (one-time setup):
   ```bash
   openssl req -new -x509 -newkey rsa:2048 -keyout MOK.priv -outform DER -out MOK.der -nodes -days 36500 -subj "/CN=MT7902 Driver/"
   ```
2. Enroll the key:
   ```bash
   sudo mokutil --import MOK.der
   ```
   *(Enter a password you will remember upon reboot)*.
3. Sign the compiled module:
   ```bash
   sudo /usr/src/linux-headers-$(uname -r)/scripts/sign-file sha256 MOK.priv MOK.der /lib/modules/$(uname -r)/kernel/drivers/net/wireless/mediatek/mt7902.ko
   ```
4. **Reboot**: Blue screen prompt (*Shim UEFI key management*) will appear. Select **Enroll MOK** -> **Continue** -> Enter your password -> **Reboot**.

---

## ⚡ Matching Windows Connectivity & Latency

To obtain the exact same stability, throughput, and ping consistency as the official Windows driver:

### 1. Disable Aggressive PCIe Power Management (ASPM)
If you notice ping latency spikes or brief drops in games/video calls, modern laptops often switch the PCIe link state too aggressively.
Add `pcie_aspm=off` to your kernel boot parameters:
- **GRUB** (`/etc/default/grub`):
  ```bash
  GRUB_CMDLINE_LINUX_DEFAULT="... pcie_aspm=off"
  sudo update-grub  # Ubuntu/Debian
  sudo grub2-mkconfig -o /boot/grub2/grub.cfg  # Fedora
  ```

### 2. Enable Wi-Fi 6E (6 GHz Band) Regulatory Domain
By default, Linux kernels boot into the conservative `00` (World) regulatory domain which locks out the 6 GHz spectrum.
Set your local regulatory country code (e.g., `US`, `GB`, `DE`, `IN`):
```bash
sudo iw reg set US
```
To make it permanent, edit `/etc/default/crda` or `/etc/conf.d/wireless-regdom`:
```text
REGDOMAIN=US
```

### 3. Disable Wi-Fi Power Save (Optional for Ultra-Low Latency)
```bash
sudo iw dev wlan0 set power_save off
```

---

## 🔍 Verification Commands

Check that your card is detected and active:

```bash
# 1. Check kernel ring buffer
sudo dmesg | grep -E "mt7902|wlan"

# 2. Verify wireless interface is registered
iw dev

# 3. Check physical link status
ip link show

# 4. Scan for available Wi-Fi 6 / 6E networks
nmcli device wifi list
```

---

## 🧹 Uninstallation

To cleanly remove the driver and restore default kernel behavior:
```bash
cd mt7902-linux-driver
sudo ./uninstall.sh
```

---

## 📄 License
This project is licensed under the **GNU General Public License v2.0 (GPL-2.0)**.
Firmware files are property of MediaTek Inc. and distributed under redistributable binary firmware terms.
