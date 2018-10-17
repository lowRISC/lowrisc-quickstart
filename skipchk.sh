echo Checking $1
SKIPLST='/dev/xyzzy'
for uuid in `grep '^UUID=' /etc/fstab | cut -d \  -f1 | sed -e 's/=/="/' -e 's/$/"/'`; do
for i in `lsblk -P -o NAME,UUID|tr \  ,`; do
    if [ `echo $i | cut -d , -f2` = $uuid ]
    then
        SKIP=`echo $i | cut -d \" -f2 | sed -e 's=^=/dev/=' -e 's=[0-9]$=='`
#        echo Skipping $SKIP, matched from /etc/fstab\!;
        SKIPLST=`echo "$SKIPLST" "$SKIP"`
    fi
    done
done
#echo $SKIPLST
for dev in $SKIPLST; do
#    echo x$1 x$dev
    if [ x$1 = x$dev ]
    then
        echo ALERT! aborting because disk parameter provided is used in /etc/fstab!
        exit 1
    fi
done
