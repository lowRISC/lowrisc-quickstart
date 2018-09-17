echo ' # partition table of image\' \
     'label: dos\' \
     'label-id: 0xdeadbeef\' \
     'unit: sectors\' \
     '\' \
     '   image1 : start=     2048, size=    65535, Id= c, bootable\' \
     '   image2 : start=    67584, size=  2097152, Id=83\' \
     '   image3 : start=  2164736, size=  1048576, Id=82\' \
     '   image4 : start=        0, size=        0, Id= 0\' \
    | tr '\\' '\012' | sed 's=^\ ==' | /sbin/sfdisk -f $*
