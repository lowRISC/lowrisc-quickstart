source ./skipchk.sh
echo ' # partition table of image\' \
     'label: dos\' \
     'label-id: 0xdeadbeef\' \
     'unit: sectors\' \
     '\' \
     '    2048      65535   c  *\' \
     '   67584    4194304   L  -\' \
     '   4261888  1048576   S  -\' \
     '   5310464        +   L  -\' \
    | tr '\\' '\012' | sed 's=^\ ==' | tee sfdisk.log | /sbin/sfdisk -f $*
sleep 2
