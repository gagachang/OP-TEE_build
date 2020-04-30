################################################################################
# Following variables defines how the NS_USER (Non Secure User - Client
# Application), NS_KERNEL (Non Secure Kernel), S_KERNEL (Secure Kernel) and
# S_USER (Secure User - TA) are compiled
################################################################################
override COMPILE_NS_USER   := 32
override COMPILE_NS_KERNEL := 32
override COMPILE_S_USER    := 32
override COMPILE_S_KERNEL  := 32

# Need to set this before including common.mk
BR2_TARGET_GENERIC_GETTY ?= y
BR2_TARGET_GENERIC_GETTY_PORT ?= ttymxc1

include common.mk

################################################################################
# Paths to git projects and various binaries
################################################################################
OPTEE_PATH		?= $(ROOT)/optee_os
U-BOOT_PATH		?= $(ROOT)/u-boot
U-BOOT_IMAGE		?= $(U-BOOT_PATH)/u-boot.imx
IMX6Q_SABRELITE_FIRMWARE_PATH ?= $(BUILD_PATH)/imx6/BD-SL_imx6q_sabrelite
IMX6Q_SABRELITE_UBOOT_ENV     ?= $(ROOT)/out/uboot.env
IMX6Q_SABRELITE_UBOOT_ENV_TXT ?= $(IMX6Q_SABRELITE_FIRMWARE_PATH)/uboot.env.txt
OPTEE_BIN		?= $(OPTEE_PATH)/out/arm/core/tee.bin
OPTEE_IMAGE		?= $(ROOT)/build/uTee

LINUX_IMAGE		?= $(LINUX_PATH)/arch/arm/boot/zImage
LINUX_DTB_IMX6Q_SABRELITE ?= $(LINUX_PATH)/arch/arm/boot/dts/imx6q-sabrelite.dtb
MODULE_OUTPUT		?= $(ROOT)/module_output

################################################################################
# Targets
################################################################################
all: u-boot buildroot optee-os linux update_rootfs
clean: u-boot-clean buildroot-clean optee-os-clean

include toolchain.mk

################################################################################
# Das U-Boot
################################################################################
U-BOOT_EXPORTS ?= CROSS_COMPILE=$(AARCH32_CROSS_COMPILE) ARCH=arm
U-BOOT_DEFCONFIG := nitrogen6q_defconfig 

.PHONY: u-boot
u-boot:
	$(U-BOOT_EXPORTS) $(MAKE) -C $(U-BOOT_PATH) $(U-BOOT_DEFCONFIG)
	$(U-BOOT_EXPORTS) $(MAKE) -C $(U-BOOT_PATH) all
	$(U-BOOT_EXPORTS) $(MAKE) -C $(U-BOOT_PATH) tools

u-boot-clean: u-boot-env-clean
	$(U-BOOT_EXPORTS) $(MAKE) -C $(U-BOOT_PATH) clean

u-boot-env: $(IMX6Q_SABRELITE_UBOOT_ENV_TXT) u-boot
	mkdir -p $(ROOT)/out
	$(U-BOOT_PATH)/tools/mkenvimage -s 0x4000 \
					-o $(IMX6Q_SABRELITE_UBOOT_ENV) \
					$(IMX6Q_SABRELITE_UBOOT_ENV_TXT)

u-boot-env-clean:
	rm -f $(IMX6Q_SABRELITE_UBOOT_ENV)

################################################################################
# Linux kernel
################################################################################
LINUX_DEFCONFIG_COMMON_ARCH := arm
LINUX_DEFCONFIG_COMMON_FILES := $(LINUX_PATH)/arch/arm/configs/imx_v6_v7_defconfig

linux-defconfig: $(LINUX_PATH)/.config

LINUX_COMMON_FLAGS += ARCH=arm

linux: linux-common
	$(MAKE) -C $(LINUX_PATH) $(LINUX_COMMON_FLAGS) INSTALL_MOD_STRIP=1 INSTALL_MOD_PATH=$(MODULE_OUTPUT) modules_install

linux-defconfig-clean: linux-defconfig-clean-common

LINUX_CLEAN_COMMON_FLAGS += ARCH=arm

linux-clean: linux-clean-common

LINUX_CLEANER_COMMON_FLAGS += ARCH=arm

linux-cleaner: linux-cleaner-common

################################################################################
# OP-TEE
################################################################################
OPTEE_OS_COMMON_FLAGS += PLATFORM=imx-mx6qsabrelite
OPTEE_OS_COMMON_FLAGS += CFG_BUILT_IN_ARGS=y \
			 CFG_DT_ADDR=0x18000000 \
			 CFG_NXP_CAAM=n

optee-os: optee-os-common
	$(U-BOOT_PATH)/tools/mkimage -A arm -O linux -C none \
		-a 0x4dffffe4 -e 0x4e000000 -d $(OPTEE_BIN) uTee

OPTEE_OS_CLEAN_COMMON_FLAGS += PLATFORM=imx-mx6qsabrelite

optee-os-clean: optee-os-clean-common optee-os-mkimage-clean

optee-os-mkimage-clean:
	rm -f $(OPTEE_IMAGE)

################################################################################
# Root FS
################################################################################
.PHONY: update_rootfs
# Make sure this is built before the buildroot target which will create the
# root file system based on what's in $(BUILDROOT_TARGET_ROOT)
buildroot: update_rootfs
update_rootfs: optee-os u-boot-env linux u-boot
	@mkdir -p --mode=755 $(BUILDROOT_TARGET_ROOT)/boot
	@mkdir -p --mode=755 $(BUILDROOT_TARGET_ROOT)/usr/bin
	@install -v -p --mode=755 $(LINUX_DTB_IMX6Q_SABRELITE) $(BUILDROOT_TARGET_ROOT)/boot/imx6q-sabrelite.dtb
	@install -v -p --mode=755 $(LINUX_IMAGE) $(BUILDROOT_TARGET_ROOT)/boot/zImage
	@install -v -p --mode=755 $(OPTEE_IMAGE) $(BUILDROOT_TARGET_ROOT)/boot/uTee
	@install -v -p --mode=755 $(IMX6Q_SABRELITE_UBOOT_ENV) $(BUILDROOT_TARGET_ROOT)/boot/uboot.env
	@cd $(MODULE_OUTPUT) && find . | cpio -pudm $(BUILDROOT_TARGET_ROOT)

# Creating images etc, could wipe out a drive on the system, therefore we don't
# want to automate that in script or make target. Instead we just simply provide
# the steps here.
.PHONY: img-help
img-help:
	@echo "$$ fdisk /dev/sdx   # where sdx is the name of your sd-card"
	@echo "   > p             # prints partition table"
	@echo "   > d             # repeat until all partitions are deleted"
	@echo "   > n             # create a new partition"
	@echo "   > p             # create primary"
	@echo "   > 1             # make it the first partition"
	@echo "   > <enter>       # use the default sector"
	@echo "   > +32M          # create a boot partition with 32MB of space"
	@echo "   > n             # create rootfs partition"
	@echo "   > p"
	@echo "   > 2"
	@echo "   > <enter>"
	@echo "   > <enter>       # fill the remaining disk, adjust size to fit your needs"
	@echo "   > t             # change partition type"
	@echo "   > 1             # select first partition"
	@echo "   > e             # use type 'e' (FAT16)"
	@echo "   > a             # make partition bootable"
	@echo "   > 1             # select first partition"
	@echo "   > p             # double check everything looks right"
	@echo "   > w             # write partition table to disk."
	@echo ""
	@echo "run the following as root"
	@echo "   $$ cd $(ROOT)/u-boot"
	@echo "   $$ dd if=u-boot.imx of=/dev/sdx bs=512 seek=2 conv=sync conv=notrunc"
	@echo ""
	@echo "run the following as root"
	@echo "   $$ mkfs.vfat -F16 -n BOOT /dev/sdx1"
	@echo "   $$ mkdir -p /media/boot"
	@echo "   $$ mount /dev/sdx1 /media/boot"
	@echo "   $$ cd /media"
	@echo "   $$ gunzip -cd $(ROOT)/out-br/images/rootfs.cpio.gz | sudo cpio -idmv \"boot/*\""
	@echo "   $$ umount boot"
	@echo ""
	@echo "run the following as root"
	@echo "   $$ mkfs.ext4 -L rootfs /dev/sdx2"
	@echo "   $$ mkdir -p /media/rootfs"
	@echo "   $$ mount /dev/sdx2 /media/rootfs"
	@echo "   $$ cd rootfs"
	@echo "   $$ gunzip -cd $(ROOT)/out-br/images/rootfs.cpio.gz | sudo cpio -idmv"
	@echo "   $$ rm -rf /media/rootfs/boot/*"
	@echo "   $$ cd .. && umount rootfs"
	@echo ""
	@echo "boot the board, run the following in the u-boot command line"
	@echo "   $$ setenv bootargs console=ttymxc1,115200 root=/dev/mmcblk0p2 rootwait rw fixrtc"
	@echo "   $$ load mmc 0:1 0x12000000 zImage"
	@echo "   $$ load mmc 0:1 0x18000000 imx6q-sabrelite.dtb"
	@echo "   $$ load mmc 0:1 0x20000000 uTee"
	@echo "   $$ bootm 0x20000000 - 0x18000000"
