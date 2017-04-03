#!/bin/bash

# Detect boot strategy, EFI or BIOS
if [ -f ${BINARIES_DIR}/efi-part/startup.nsh ]; then
  BOOT_TYPE=efi
  # grub.cfg needs customization for EFI since the root partition is
  # number 2, and bzImage is in the EFI partition (1)
  cat >${BINARIES_DIR}/efi-part/EFI/BOOT/grub.cfg <<__EOF__
set default="0"
set timeout="5"

menuentry "Buildroot" {
	linux /bzImage rootwait console=tty1
}
__EOF__
else
  BOOT_TYPE=bios
  # Copy grub 1st stage to binaries, required for genimage
  cp -f ${HOST_DIR}/usr/lib/grub/i386-pc/boot.img ${BINARIES_DIR}
fi

BOARD_DIR="$(dirname $0)"
GENIMAGE_CFG="${BOARD_DIR}/genimage-${BOOT_TYPE}.cfg"
GENIMAGE_TMP="${BUILD_DIR}/genimage.tmp"

rm -rf "${GENIMAGE_TMP}"

genimage                           \
       --rootpath "${TARGET_DIR}"     \
       --tmppath "${GENIMAGE_TMP}"    \
       --inputpath "${BINARIES_DIR}"  \
       --outputpath "${BINARIES_DIR}" \
       --config "${GENIMAGE_CFG}"
status=$?
if [ $status -ne 0 ]
then
    echo "Error: genimage" >&2
    exit $status
fi

# create the swupdate image:
CONTAINER_VER="1.0"
PRODUCT_NAME="pc_x86_64-rt"
FILES="sw-description disk.img"
rm -f ${BINARIES_DIR}/sw-description
rm -f ${BINARIES_DIR}/${PRODUCT_NAME}_${CONTAINER_VER}.swu
cp ${BOARD_DIR}/sw-description ${BINARIES_DIR}
pushd ${BINARIES_DIR}
for i in $FILES;do
	echo $i;done | cpio -ov -H crc >  ${PRODUCT_NAME}_${CONTAINER_VER}.swu
popd

exit $?
