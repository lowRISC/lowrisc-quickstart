source ./skipchk.sh
echo ' # partition table of image\' \
     'label: dos\' \
     'label-id: 0xc001f00d\' \
     'unit: sectors\' \
     '\' \
     '   image1 : start=     2048, size=    65535, Id= 6, bootable\' \
    | tr '\\' '\012' | sed 's=^\ ==' | /sbin/sfdisk -f $*
echo ", +" | /sbin/sfdisk -f -N 1 $*
