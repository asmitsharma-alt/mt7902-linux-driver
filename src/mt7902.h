/*
 * Standalone Linux Kernel Driver for MediaTek MT7902 Wi-Fi 6E (802.11ax)
 *
 * Hardware: MediaTek MT7902 Wireless LAN Card
 * PCI Device ID: 14c3:7902
 *
 * Copyright (C) 2026 MediaTek Inc. / Open Source Community
 * SPDX-License-Identifier: GPL-2.0-only
 */

#ifndef __MT7902_H
#define __MT7902_H

#include <linux/types.h>
#include <linux/pci.h>
#include <linux/dma-mapping.h>
#include <linux/interrupt.h>
#include <linux/firmware.h>
#include <linux/spinlock.h>
#include <linux/mutex.h>
#include <linux/skbuff.h>
#include <net/mac80211.h>

#define DRIVER_NAME    "mt7902"
#define DRIVER_VERSION "1.0.0"

/* PCI Identification */
#define PCI_VENDOR_ID_MEDIATEK 0x14C3
#define PCI_DEVICE_ID_MT7902   0x7902

/* Firmware Filenames */
#define MT7902_FIRMWARE_PATCH "mediatek/WIFI_MT7902_patch_mcu_1_1_hdr.bin"
#define MT7902_FIRMWARE_RAM   "mediatek/WIFI_RAM_CODE_MT7902_1.bin"

/* Ring Buffer Configurations */
#define MT7902_TX_RING_SIZE   512
#define MT7902_RX_RING_SIZE   512

/* Hardware Registers (MMIO BAR0) */
#define MT_MCU_PCIE_REMAP_BASE 0x0740
#define MT_WPDMA_GLO_CFG       0x4208
#define MT_WPDMA_RST_IDX       0x420C
#define MT_TX_RING_BASE(q)     (0x4000 + ((q) * 0x10))
#define MT_RX_RING_BASE(q)     (0x4100 + ((q) * 0x10))
#define MT_INT_SOURCE_CSR      0x4200
#define MT_INT_MASK_CSR        0x4204

/* Hardware DMA Descriptor Structure */
struct mt7902_dma_desc {
    __le32 buf0;
    __le32 ctrl;
    __le32 buf1;
    __le32 info;
} __packed;

/* Driver Device State */
struct mt7902_dev {
    struct pci_dev *pdev;
    void __iomem *io_base;
    struct ieee80211_hw *hw;

    /* DMA Coherent Memory */
    struct mt7902_dma_desc *tx_ring;
    dma_addr_t tx_ring_dma;
    struct sk_buff *tx_buf[MT7902_TX_RING_SIZE];
    u32 tx_head;
    u32 tx_tail;

    struct mt7902_dma_desc *rx_ring;
    dma_addr_t rx_ring_dma;
    struct sk_buff *rx_buf[MT7902_RX_RING_SIZE];
    u32 rx_head;

    /* Locking & Synchronization */
    spinlock_t lock;
    struct mutex mcu_mutex;
    struct tasklet_struct rx_tasklet;
};

/* Register Read/Write Helpers */
static inline u32 mt7902_rr(struct mt7902_dev *dev, u32 reg)
{
    return readl(dev->io_base + reg);
}

static inline void mt7902_wr(struct mt7902_dev *dev, u32 reg, u32 val)
{
    writel(val, dev->io_base + reg);
}

static inline void mt7902_set(struct mt7902_dev *dev, u32 reg, u32 mask)
{
    mt7902_wr(dev, reg, mt7902_rr(dev, reg) | mask);
}

static inline void mt7902_clear(struct mt7902_dev *dev, u32 reg, u32 mask)
{
    mt7902_wr(dev, reg, mt7902_rr(dev, reg) & ~mask);
}

/* Subsystem Function Prototypes */
int mt7902_dma_init(struct mt7902_dev *dev);
void mt7902_dma_cleanup(struct mt7902_dev *dev);
int mt7902_mcu_init(struct mt7902_dev *dev);
int mt7902_mac80211_register(struct mt7902_dev *dev);
void mt7902_mac80211_unregister(struct mt7902_dev *dev);

#endif /* __MT7902_H */
