/*
 * Standalone Linux Kernel Driver for MediaTek MT7902 Wi-Fi 6E (802.11ax)
 * PCIe DMA ring buffer allocation and descriptor management.
 *
 * SPDX-License-Identifier: GPL-2.0-only
 */

#include "mt7902.h"

int mt7902_dma_init(struct mt7902_dev *dev)
{
    int i;

    /* Allocate coherent memory for TX ring */
    dev->tx_ring = dma_alloc_coherent(&dev->pdev->dev,
                                      sizeof(struct mt7902_dma_desc) * MT7902_TX_RING_SIZE,
                                      &dev->tx_ring_dma, GFP_KERNEL);
    if (!dev->tx_ring)
        return -ENOMEM;

    /* Allocate coherent memory for RX ring */
    dev->rx_ring = dma_alloc_coherent(&dev->pdev->dev,
                                      sizeof(struct mt7902_dma_desc) * MT7902_RX_RING_SIZE,
                                      &dev->rx_ring_dma, GFP_KERNEL);
    if (!dev->rx_ring) {
        dma_free_coherent(&dev->pdev->dev, sizeof(struct mt7902_dma_desc) * MT7902_TX_RING_SIZE,
                          dev->tx_ring, dev->tx_ring_dma);
        return -ENOMEM;
    }

    /* Pre-populate RX ring with network sk_buffs */
    for (i = 0; i < MT7902_RX_RING_SIZE; i++) {
        struct sk_buff *skb = dev_alloc_skb(2048);
        dma_addr_t dma_addr;

        if (!skb)
            continue;

        dma_addr = dma_map_single(&dev->pdev->dev, skb->data, 2048, DMA_FROM_DEVICE);
        if (dma_mapping_error(&dev->pdev->dev, dma_addr)) {
            dev_kfree_skb(skb);
            continue;
        }

        dev->rx_buf[i] = skb;
        dev->rx_ring[i].buf0 = cpu_to_le32(lower_32_bits(dma_addr));
        dev->rx_ring[i].ctrl = cpu_to_le32(2048);
    }

    /* Program DMA base addresses into hardware registers */
    mt7902_wr(dev, MT_TX_RING_BASE(0), lower_32_bits(dev->tx_ring_dma));
    mt7902_wr(dev, MT_RX_RING_BASE(0), lower_32_bits(dev->rx_ring_dma));

    /* Enable DMA Engine in WPDMA_GLO_CFG */
    mt7902_set(dev, MT_WPDMA_GLO_CFG, 0x00000030);

    return 0;
}

void mt7902_dma_cleanup(struct mt7902_dev *dev)
{
    int i;

    /* Stop DMA engine */
    mt7902_clear(dev, MT_WPDMA_GLO_CFG, 0x00000030);

    /* Free RX buffers */
    for (i = 0; i < MT7902_RX_RING_SIZE; i++) {
        if (dev->rx_buf[i]) {
            dev_kfree_skb(dev->rx_buf[i]);
            dev->rx_buf[i] = NULL;
        }
    }

    /* Free coherent descriptor memory */
    if (dev->tx_ring) {
        dma_free_coherent(&dev->pdev->dev, sizeof(struct mt7902_dma_desc) * MT7902_TX_RING_SIZE,
                          dev->tx_ring, dev->tx_ring_dma);
        dev->tx_ring = NULL;
    }

    if (dev->rx_ring) {
        dma_free_coherent(&dev->pdev->dev, sizeof(struct mt7902_dma_desc) * MT7902_RX_RING_SIZE,
                          dev->rx_ring, dev->rx_ring_dma);
        dev->rx_ring = NULL;
    }
}
