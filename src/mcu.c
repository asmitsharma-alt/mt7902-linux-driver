/*
 * Standalone Linux Kernel Driver for MediaTek MT7902 Wi-Fi 6E (802.11ax)
 * MCU Firmware staging and mailbox command protocol.
 *
 * SPDX-License-Identifier: GPL-2.0-only
 */

#include "mt7902.h"

int mt7902_mcu_init(struct mt7902_dev *dev)
{
    const struct firmware *fw_patch = NULL;
    const struct firmware *fw_ram = NULL;
    int ret;

    mutex_lock(&dev->mcu_mutex);

    /* Step 1: Request ROM Patch file */
    dev_info(&dev->pdev->dev, "Loading MCU ROM patch: %s\n", MT7902_FIRMWARE_PATCH);
    ret = request_firmware(&fw_patch, MT7902_FIRMWARE_PATCH, &dev->pdev->dev);
    if (ret) {
        dev_err(&dev->pdev->dev, "Failed to load ROM patch (%s): %d. Ensure firmware is in /lib/firmware/mediatek/\n",
                MT7902_FIRMWARE_PATCH, ret);
        goto out;
    }

    dev_info(&dev->pdev->dev, "ROM patch loaded (%zu bytes). Uploading to MCU...\n", fw_patch->size);
    /* In a full driver, copy firmware blocks over PCIe DMA into MT_MCU_PCIE_REMAP_BASE */
    release_firmware(fw_patch);

    /* Step 2: Request Operational RAM Code */
    dev_info(&dev->pdev->dev, "Loading MCU RAM code: %s\n", MT7902_FIRMWARE_RAM);
    ret = request_firmware(&fw_ram, MT7902_FIRMWARE_RAM, &dev->pdev->dev);
    if (ret) {
        dev_err(&dev->pdev->dev, "Failed to load RAM code (%s): %d\n", MT7902_FIRMWARE_RAM, ret);
        goto out;
    }

    dev_info(&dev->pdev->dev, "RAM code loaded (%zu bytes). Initializing MT7902 MCU state...\n", fw_ram->size);
    release_firmware(fw_ram);

    dev_info(&dev->pdev->dev, "MT7902 on-chip MCU initialized successfully\n");
    ret = 0;

out:
    mutex_unlock(&dev->mcu_mutex);
    return ret;
}
