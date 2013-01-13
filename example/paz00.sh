#!/bin/bash -x

CROSS_COMPILER=arm-linux-gnueabihf-
MAKE="make -j4"
BCT="paz00-micron-toshiba-8g.bct"

UBOOT_DIR="u-boot-tegra"
UBOOT_REPO="-b next git://git.denx.de/u-boot-tegra.git"

KERNEL_DIR="ac100-kernel"
KERNEL_REPO="-b linux-ac100-3.8 git://gitorious.org/~marvin24/ac100/marvin24s-kernel.git"

TEGRARCM_DIR="tegrarcm"
TEGRARCM_REPO="git://nv-tegra.nvidia.com/tools/tegrarcm.git"

#IMGURL="http://cdimage.ubuntu.com/daily-live/current"
#BASEIMG="raring-desktop-armhf+omap4.img"
IMGURL="http://ports.ubuntu.com/ubuntu-ports/dists/raring/main/installer-armhf/current/images/omap4/netboot"
UINITRD="uInitrd"
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

rm -rf "$MNTPNT"
mkdir -p $MNTPNT
wget -c $IMGURL/$UINITRD
dd if=$UINITRD of=initrd.cpio.gz bs=64 skip=1
pushd $MNTPNT
gzip -cd  ../initrd.cpio.gz | fakeroot -- cpio -i -d -H newc --no-absolute-filenames
popd

update_dir "$UBOOT_DIR" "$UBOOT_REPO"
$MAKE paz00_config CROSS_COMPILE=$CROSS_COMPILER
$MAKE CROSS_COMPILE=$CROSS_COMPILER
popd

update_dir "$KERNEL_DIR" "$KERNEL_REPO"
$MAKE paz00_defconfig ARCH=arm
$MAKE zImage dtbs modules ARCH=arm CROSS_COMPILE=$CROSS_COMPILER INSTALL_MOD_PATH=$MNTPNT INSTALL_MOD_STRIP=1
rm -rf $MNTPNT/lib/modules
$MAKE modules_install ARCH=arm CROSS_COMPILE=$CROSS_COMPILER INSTALL_MOD_PATH=$MNTPNT INSTALL_MOD_STRIP=1
popd

update_dir "$TEGRARCM_DIR" "$TEGRARCM_REPO"
./autogen.sh
$MAKE
popd

pushd "$MNTPNT"
find . | cpio -R 0:0 -o -H newc | gzip -c9 > ../initrd.new.cpio.gz
popd
mkimage -A arm -T ramdisk -n "debian-install ramdisk" -d initrd.new.cpio.gz uInitrd.new

../create_image.pl \
	$UBOOT_DIR/u-boot-dtb-tegra.bin \
	$KERNEL_DIR/arch/arm/boot/zImage \
	uInitrd.new \
	$KERNEL_DIR/arch/arm/boot/dts/tegra20-paz00.dtb \
	uboot.scr \
	boot.img

sudo $TEGRARCM_DIR/src/tegrarcm --bct $BCT --bootloader boot.img --loadaddr 0x108000
