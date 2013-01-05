#!/bin/bash -x

CROSS_COMPILER=arm-linux-gnueabihf-
BCT="paz00-micron-toshiba-8g.bct"

UBOOT_DIR="u-boot-tegra"
UBOOT_REPO="-b next git://git.denx.de/u-boot-tegra.git"

KERNEL_DIR="ac100-kernel"
KERNEL_REPO="-b linux-ac100-3.8 git://gitorious.org/~marvin24/ac100/marvin24s-kernel.git"

TEGRARCM_DIR="tegrarcm"
TEGRARCM_REPO="git://nv-tegra.nvidia.com/tools/tegrarcm.git"

IMGURL="http://cdimage.ubuntu.com/daily-live/current"
BASEIMG="raring-desktop-armhf+omap4.img"
MNTPNT=`pwd`/instimg

update_dir() {
    DIR=$1
    REPO=$2
    if [ ! -e $DIR ]; then
	git clone $REPO $DIR
	pushd $DIR
    else
	pushd $DIR
	git clean -fdx
	git pull
    fi
}

update_dir "$UBOOT_DIR" "$UBOOT_REPO"
make paz00_config CROSS_COMPILE=$CROSS_COMPILER
make CROSS_COMPILE=$CROSS_COMPILER
popd

update_dir "$KERNEL_DIR" "$KERNEL_REPO"
make paz00_defconfig ARCH=arm
make zImage dtbs modules ARCH=arm CROSS_COMPILE=$CROSS_COMPILER INSTALL_MOD_PATH=/tmp INSTALL_MOD_STRIP=1
popd

update_dir "$TREGRARCM_DIR" "$TEGRARCM_REPO"
./autogen.sh
make
popd

mkdir -p $MNTPNT
wget -c $IMGURL/$BASEIMG
LOOPDEV=/dev/mapper/`sudo losetup -f|sed -e "s/\/dev\///"`p2
sudo kpartx -a -v $BASEIMG
sudo mount $LOOPDEV $MNTPNT
sudo mount -oloop $MNTPNT/casper/filesystem.squashfs $MNTPNT/install
cp $MNTPNT/casper/filesystem.initrd-omap4 initrd.img
mkimage -A arm -T ramdisk -C lzma -n initrd -d initrd.img initrd.uimg
sudo umount $MNTPNT/install
sudo umount $MNTPNT
sudo kpartx -d $BASEIMG

../create_image.pl \
	$UBOOT_DIR/u-boot-dtb-tegra.bin \
	$KERNEL_DIR/arch/arm/boot/zImage \
	initrd.uimg \
	$KERNEL_DIR/arch/arm/boot/dts/tegra20-paz00.dtb \
	uboot.scr \
	boot.img

sudo $TEGRARCM_DIR/src/tegrarcm --bct $BCT --bootloader boot.img --loadaddr 0x108000
