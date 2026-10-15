# Makefile for MediaTek MT7902 Linux Kernel Driver

MODULE_NAME := mt7902

obj-m += $(MODULE_NAME).o
$(MODULE_NAME)-y := src/main.o src/dma.o src/mcu.o src/mac80211.o

KDIR ?= /lib/modules/$(shell uname -r)/build
PWD := $(shell pwd)

EXTRA_CFLAGS += -I$(PWD)/src -DDEBUG

default:
	$(MAKE) -C $(KDIR) M=$(PWD) modules

clean:
	$(MAKE) -C $(KDIR) M=$(PWD) clean
	rm -rf *.o src/*.o modules.order Module.symvers *.mod.c *.mod .tmp_versions

install: default
	mkdir -p /lib/modules/$(shell uname -r)/kernel/drivers/net/wireless/mediatek/
	cp $(MODULE_NAME).ko /lib/modules/$(shell uname -r)/kernel/drivers/net/wireless/mediatek/
	mkdir -p /lib/firmware/mediatek/
	cp firmware/*.bin /lib/firmware/mediatek/ 2>/dev/null || true
	depmod -a
	modprobe -v $(MODULE_NAME)

uninstall:
	modprobe -r $(MODULE_NAME) 2>/dev/null || true
	rm -f /lib/modules/$(shell uname -r)/kernel/drivers/net/wireless/mediatek/$(MODULE_NAME).ko
	depmod -a
