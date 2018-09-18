echo ' # partition table of image\' \
     'label: dos\' \
     'label-id: 0xdeadbeef\' \
     'unit: sectors\' \
     '\' \
     '   image1 : start=     2048, size=    65535, Id= c, bootable\' \
     '   image2 : start=    67584, size=  4194304, Id=83\' \
     '   image3 : start=  4261888, size=  1048576, Id=82\' \
     '   image4 : start=  5310464, size=  1048576, Id=83\' \
    | tr '\\' '\012' | sed 's=^\ ==' | /sbin/sfdisk -f $*
echo ", +" | /sbin/sfdisk -f -N 4 $*
