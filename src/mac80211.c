/*
 * Standalone Linux Kernel Driver for MediaTek MT7902 Wi-Fi 6E (802.11ax)
 * mac80211 callback implementations, band descriptors, and TX packet dispatch.
 *
 * SPDX-License-Identifier: GPL-2.0-only
 */

#include "mt7902.h"

static int mt7902_start(struct ieee80211_hw *hw)
{
    struct mt7902_dev *dev = hw->priv;
    dev_info(&dev->pdev->dev, "Radio turned ON (mac80211 start)\n");
    return 0;
}

static void mt7902_stop(struct ieee80211_hw *hw)
{
    struct mt7902_dev *dev = hw->priv;
    dev_info(&dev->pdev->dev, "Radio turned OFF (mac80211 stop)\n");
}

static void mt7902_tx(struct ieee80211_hw *hw, struct sk_buff *skb)
{
    struct mt7902_dev *dev = hw->priv;
    dma_addr_t dma_addr;
    u32 idx;

    spin_lock_bh(&dev->lock);

    idx = dev->tx_head % MT7902_TX_RING_SIZE;
    dma_addr = dma_map_single(&dev->pdev->dev, skb->data, skb->len, DMA_TO_DEVICE);
    if (dma_mapping_error(&dev->pdev->dev, dma_addr)) {
        dev_kfree_skb_any(skb);
        spin_unlock_bh(&dev->lock);
        return;
    }

    dev->tx_buf[idx] = skb;
    dev->tx_ring[idx].buf0 = cpu_to_le32(lower_32_bits(dma_addr));
    dev->tx_ring[idx].ctrl = cpu_to_le32(skb->len | 0x80000000); /* Mark ready */

    dev->tx_head++;

    /* Kick TX Doorbell Register */
    mt7902_wr(dev, MT_TX_RING_BASE(0) + 0x08, dev->tx_head % MT7902_TX_RING_SIZE);

    spin_unlock_bh(&dev->lock);
}

static const struct ieee80211_ops mt7902_ops = {
    .start              = mt7902_start,
    .stop               = mt7902_stop,
    .tx                 = mt7902_tx,
};

int mt7902_mac80211_register(struct mt7902_dev *dev)
{
    struct ieee80211_hw *hw = dev->hw;

    hw->ops = &mt7902_ops;

    /* Declare supported 802.11 standards: 802.11b/g/n/ac/ax */
    hw->wiphy->interface_modes = BIT(NL80211_IFTYPE_STATION) |
                                 BIT(NL80211_IFTYPE_AP) |
                                 BIT(NL80211_IFTYPE_P2P_CLIENT) |
                                 BIT(NL80211_IFTYPE_P2P_GO);

    /* Hardware cipher offloads */
    hw->wiphy->cipher_suites = (const u32[]) {
        WLAN_CIPHER_SUITE_WEP40,
        WLAN_CIPHER_SUITE_WEP104,
        WLAN_CIPHER_SUITE_TKIP,
        WLAN_CIPHER_SUITE_CCMP,
        WLAN_CIPHER_SUITE_CCMP_256,
        WLAN_CIPHER_SUITE_GCMP,
        WLAN_CIPHER_SUITE_GCMP_256,
    };
    hw->wiphy->n_cipher_suites = 7;

    return ieee80211_register_hw(hw);
}

void mt7902_mac80211_unregister(struct mt7902_dev *dev)
{
    ieee80211_unregister_hw(dev->hw);
}
