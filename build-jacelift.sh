#!/bin/bash

WORK_DIR=$PWD

read_variable()
{
	read -e -p "$1: " -i "$2" INPUT_VAR
}

mount_image()
{
	LOOP_DEV="$(losetup -P -f --show $1)"
	mount "$LOOP_DEV"p2 $IMAGE_WORK_PATH
}

umount_image()
{
	umount $IMAGE_WORK_PATH
	losetup -d $LOOP_DEV

}

cleanup()
{
	echo "Cleanup."
	rm -f $OPENWRT_WORK_IMG
	rm -f $ARMBIAN_WORK_IMG
	rm -rf $OPENWRT_WORK_PATH
	rm -rf $IMAGE_WORK_PATH
}

read_variable "Enter OpenWRT image path" "./openwrt.img"
OPENWRT_IMG="$INPUT_VAR"
echo "【】输入的openwrt.img文件为：$OPENWRT_IMG。"

read_variable "Enter Armbian image path" "./armbian.img"
ARMBIAN_IMG="$INPUT_VAR"
echo "【】输入的armbian.img文件为：$ARMBIAN_IMG。"

echo "OpenWRT Image: $OPENWRT_IMG"
echo "Armbian Image: $ARMBIAN_IMG"

OPENWRT_WORK_IMG="$OPENWRT_IMG".tmp
ARMBIAN_WORK_IMG="$ARMBIAN_IMG".tmp
OPENWRT_WORK_PATH="$WORK_DIR"/openwrt
IMAGE_WORK_PATH="$WORK_DIR"/image

cleanup

echo "Create work images."

echo
echo "【01】复制openwrt.img 为 openwrt.img.tmp，$OPENWRT_WORK_IMG"
cp $OPENWRT_IMG $OPENWRT_WORK_IMG

echo
echo "【02】复制armbian.img 为 armbian.img.tmp，$ARMBIAN_WORK_IMG"
cp $ARMBIAN_IMG $ARMBIAN_WORK_IMG

echo "Create work directories."
echo
echo "【03】创建目录openwrt：$OPENWRT_WORK_PATH"
mkdir -p $OPENWRT_WORK_PATH
echo
echo "【04】创建目录image：$IMAGE_WORK_PATH"
mkdir -p $IMAGE_WORK_PATH



echo "=================Start:openwrt.img========================"
echo "Copy files from OpenWRT image."
echo
echo "【05】挂载openwrt.img.tmp的p2分区（root分区） 到 ./image目录。"
mount_image $OPENWRT_WORK_IMG
echo
echo "【06】移动openwrt.img.tmp的p2分区的所有文件 到 ./openwrt/目录下。"
mv "$IMAGE_WORK_PATH"/* $OPENWRT_WORK_PATH
echo
echo "【07】删除./openwrt/lib/目录下的： firmware 和 modules 两个文件夹。"
rm -rf "$OPENWRT_WORK_PATH"/lib/firmware
rm -rf "$OPENWRT_WORK_PATH"/lib/modules
echo
echo "【08】卸载openwrt.img.tmp的挂载。"
umount_image $OPENWRT_IMG
echo "=================End:openwrt.img==========================="



echo
echo "===========================Start:armbian.img==============================="
echo "Copy files from Armbian image."
echo
echo "【09】挂载./armbian.img.tmp的p2分区（root分区） 到 ./image目录。"
mount_image $ARMBIAN_WORK_IMG
echo
echo "【10】移动armbian.img.tmp的p2分区（root分区）的 modules和firmware 目录到 ./openwrt/lib/目录下。"
mv "$IMAGE_WORK_PATH"/lib/modules "$OPENWRT_WORK_PATH"/lib/
mv "$IMAGE_WORK_PATH"/lib/firmware "$OPENWRT_WORK_PATH"/lib/
echo
echo "【11】移动armbian.img.tmp的p2分区（root分区）的 modprobe.d和fstab 到./openwrt/etc/目录下。"
mv "$IMAGE_WORK_PATH"/etc/modprobe.d "$OPENWRT_WORK_PATH"/etc/
mv "$IMAGE_WORK_PATH"/etc/fstab "$OPENWRT_WORK_PATH"/etc
echo
echo "【12】创建软链接: ./openwrt/lib/modules/* "
for d in `find "$OPENWRT_WORK_PATH"/lib/modules/* -maxdepth 0 -type d`
do
	echo "Link modules in $d."
	cd $d
	for x in `find -name *.ko`
	do
    		ln -s $x .
	done
done
cd $WORK_DIR

echo
echo "【13】修改boot script文件：./openwrt/etc/init.d/boot。"
sed -i '39iulimit -n 51200' "$OPENWRT_WORK_PATH"/etc/init.d/boot

echo
echo "【14】复制./files/目录下的内容 到 ./openwrt/目录下，Copy defaut configs。"
rsync -a "$WORK_DIR"/files/ $OPENWRT_WORK_PATH

echo "Create firmware image."
echo
echo "【15】删除armbian.img.tmp的p2分区下（root分区）的所有内容。"
rm -rf "$IMAGE_WORK_PATH"/*

echo
echo "【16】将./openwrt/目录下的所有内容 移动 到armbian.img.tmp的p2分区的挂载目录下（root分区）。"
mv "$OPENWRT_WORK_PATH"/* $IMAGE_WORK_PATH
sync

echo
echo "【17】卸载armbian.img.tmp镜像的挂载。"
umount_image $ARMBIAN_WORK_IMG
echo "===============================End:armbian.img=================================="

echo
echo "【18】将移植好的armbian.img.tmp镜像文件命名为：openwrt-OneCloud.img。"
mv $ARMBIAN_WORK_IMG openwrt-OneCloud.img

echo
echo "【19】移植好的openwrt镜像文件为：openwrt-OneCloud.img"

echo
echo "接下来准备使用gzip打包压缩，如果不需要压缩，请在30秒内按 Ctrl+C 终止即可。"

echo
echo "开始倒计时：30秒，然后开始打包压缩。。。"

echo
sleep 30s

echo
echo "【20】删除上次打包遗留的压缩包：openwrt-OneCloud.img.gz"
rm -f openwrt-OneCloud.img.gz

echo
echo "【21】使用gzip打包压缩移植好的openwrt镜像文件openwrt-OneCloud.img"
gzip openwrt-OneCloud.img

cleanup

echo "All done. Firmware Image: openwrt-OneCloud.img.gz"




build-openwrt()
{
echo "构建openwrt-OneCloud.img步骤："
echo
echo "存储空间要求："
echo "可用空间 ≥2 倍(armbian.img+openwrt.img)+files"
echo
echo "openwrt目录：用来暂存构建openwrt所需要的内容"
echo "image目录：用于挂载镜像文件"
echo "files目录：用于存放需要添加到新镜像的文件"
echo
echo "【1】openwrt.img的p2分区："
echo "1.1 rm -rf /lib/firmware"
echo "1.2 rm -rf /lib/modules"
echo "1.3 mkdir -p onecloud-openwrt"
echo "1.4 mv openwrt.img的p2分区/* openwrt/"
echo
echo "【2】armbian.img的p2分区："
echo "2.1 mv armbian.img的p2分区/etc/modprobe.d openwrt/etc/"
echo "2.2 mv armbian.img的p2分区/etc/fstab openwrt/etc/"
echo "2.3 创建软链接: ./openwrt/lib/modules/*"
echo for d in `find "$OPENWRT_WORK_PATH"/lib/modules/* -maxdepth 0 -type d`
echo do
echo 	echo "Link modules in $d."
echo 	cd $d
echo 	for x in `find -name *.ko`
echo 	do
echo     		ln -s $x .
echo 	done
echo done
echo
echo "2.4 修改boot script文件：./openwrt/etc/init.d/boot。"
echo "    sed -i '39iulimit -n 51200' ./openwrt/etc/init.d/boot"
echo
echo "2.5 rsync -a files/ openwrt"
echo "2.6 rm -rf armbian.img的p2分区/*"
echo "2.7 mv openwrt/* armbian.img的p2分区/ && sync"
echo "2.8 umount armbian.img"
echo "2.9 mv armbian.img openwrt-OneCloud.img"
}