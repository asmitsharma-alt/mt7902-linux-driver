/*
 * Standalone Linux Kernel Driver for MediaTek MT7902 Wi-Fi 6E (802.11ax)
 * Main PCIe initialization, probe, remove, and driver entry.
 *
 * SPDX-License-Identifier: GPL-2.0-only
 */

#include "mt7902.h"

static int mt7902_pci_probe(struct pci_dev *pdev, const struct pci_device_id *id)
{
    struct mt7902_dev *dev;
    struct ieee80211_hw *hw;
    int ret;

    dev_info(&pdev->dev, "Initializing MediaTek MT7902 Wi-Fi 6E (14c3:7902)\n");

    ret = pcim_enable_device(pdev);
    if (ret) {
        dev_err(&pdev->dev, "Failed to enable PCIe device: %d\n", ret);
        return ret;
    }

    pci_set_master(pdev);

    /* Configure 64-bit DMA mask with 32-bit fallback */
    ret = dma_set_mask_and_coherent(&pdev->dev, DMA_BIT_MASK(64));
    if (ret) {
        ret = dma_set_mask_and_coherent(&pdev->dev, DMA_BIT_MASK(32));
        if (ret) {
            dev_err(&pdev->dev, "Failed to set DMA mask: %d\n", ret);
            return ret;
        }
    }

    /* Allocate ieee80211_hw structure */
    hw = ieee80211_alloc_hw(sizeof(struct mt7902_dev), NULL);
    if (!hw)
        return -ENOMEM;

    dev = hw->priv;
    dev->hw = hw;
    dev->pdev = pdev;
    spin_lock_init(&dev->lock);
    mutex_init(&dev->mcu_mutex);
    pci_set_drvdata(pdev, dev);

    /* Map PCIe BAR0 MMIO space */
    dev->io_base = pcim_iomap(pdev, 0, 0);
    if (!dev->io_base) {
        dev_err(&pdev->dev, "Failed to map BAR0 MMIO region\n");
        ret = -ENOMEM;
        goto err_free_hw;
    }

    /* Initialize DMA rings */
    ret = mt7902_dma_init(dev);
    if (ret) {
        dev_err(&pdev->dev, "Failed to initialize DMA rings: %d\n", ret);
        goto err_free_hw;
    }

    /* Bootstrap MCU firmware */
    ret = mt7902_mcu_init(dev);
    if (ret) {
        dev_err(&pdev->dev, "MCU firmware initialization failed: %d\n", ret);
        goto err_cleanup_dma;
    }

    /* Register with Linux mac80211 subsystem */
    ret = mt7902_mac80211_register(dev);
    if (ret) {
        dev_err(&pdev->dev, "Failed to register mac80211 hardware: %d\n", ret);
        goto err_cleanup_dma;
    }

    dev_info(&pdev->dev, "MediaTek MT7902 successfully registered as wireless interface\n");
    return 0;

err_cleanup_dma:
    mt7902_dma_cleanup(dev);
err_free_hw:
    ieee80211_free_hw(hw);
    return ret;
}

static void mt7902_pci_remove(struct pci_dev *pdev)
{
    struct mt7902_dev *dev = pci_get_drvdata(pdev);

    dev_info(&pdev->dev, "Removing MediaTek MT7902 driver\n");
    mt7902_mac80211_unregister(dev);
    mt7902_dma_cleanup(dev);
    ieee80211_free_hw(dev->hw);
}

static const struct pci_device_id mt7902_pci_table[] = {
    { PCI_DEVICE(PCI_VENDOR_ID_MEDIATEK, PCI_DEVICE_ID_MT7902) },
    { 0, }
};
MODULE_DEVICE_TABLE(pci, mt7902_pci_table);

static struct pci_driver mt7902_pci_driver = {
    .name     = DRIVER_NAME,
    .id_table = mt7902_pci_table,
    .probe    = mt7902_pci_probe,
    .remove   = mt7902_pci_remove,
};

module_pci_driver(mt7902_pci_driver);

MODULE_AUTHOR("MediaTek Open Source / Linux Community");
MODULE_DESCRIPTION("Standalone Linux Kernel Driver for MediaTek MT7902 Wi-Fi 6E");
MODULE_LICENSE("GPL");
MODULE_VERSION(DRIVER_VERSION);
