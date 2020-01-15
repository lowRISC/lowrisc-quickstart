#Vivado installs default to this address, if you used a different value, or a server
#specify the new value of XILINX_TOP in the environment
export XILINX_TOP=/opt/Xilinx
export XILINX_VIVADO=$(XILINX_TOP)/Vivado/2018.1
export PATH:=$(RISCV)/bin:$(XILINX_VIVADO)/bin:$(XILINX_TOP)/SDK/2018.1/bin:$(XILINX_TOP)/DocNav:$(PATH)
export REMOTE=192.168.0.51
export USB=xyzzy
export CARDMEM=cardmem
#export BOARD=genesys2
export BOARD=nexys4_ddr
#export CPU=ariane
export CPU=rocket

BITFILE=$(BOARD)_$(CPU)_xilinx
MD5FILE=$(shell md5sum boot.bin | cut -d\  -f1)

.SUFFIXES:

all: install

getrelease: boot.bin $(BITFILE).bit $(BUILDROOT)
cleanrelease:
	rm -f boot.bin $(BITFILE).bit $(BUILDROOT)
cleandisk:
	rm -f $(CARDMEM).log
partition: umount $(CARDMEM).log
install: umount cleandisk partition mkfs fatdisk extdisk
install-debian: umount cleandisk partition mkfs fatdisk extdisk-debian

download: $(MD5FILE)
	echo -e bin \\n put $< \\n | tftp $(REMOTE)

$(MD5FILE): boot.bin
	cp $< $@

program-cfgmem: $(BITFILE).mcs program_cfgmem_$(BOARD).tcl
	vivado -mode batch -source program_cfgmem_$(BOARD).tcl -tclargs "xc7a100t_0" $(BITFILE).mcs

fatdisk: $(CARDMEM).log boot.bin
	sudo mkdir -p /mnt/deadbeef-01
	sudo mount /dev/`grep deadbeef-01 $< | cut -d\" -f2` /mnt/deadbeef-01
	sudo cp boot.bin /mnt/deadbeef-01
	sudo umount /mnt/deadbeef-01

extdisk: $(CARDMEM).log $(BUILDROOT)
	sudo mkdir -p /mnt/deadbeef-02
	sudo mount -t ext4 /dev/`grep deadbeef-02 $< | cut -d\" -f2` /mnt/deadbeef-02
	sudo tar xf $(BUILDROOT) -C /mnt/deadbeef-02
	sudo umount /mnt/deadbeef-02

extdisk-debian: $(CARDMEM).log $(BUILDROOT)
	sudo mkdir -p /mnt/deadbeef-02
	sudo mount -t ext4 /dev/`grep deadbeef-02 $< | cut -d\" -f2` /mnt/deadbeef-02
	sudo tar xJf rootfs.tar.xz -C /mnt/deadbeef-02
	sudo umount /mnt/deadbeef-02

part: $(CARDMEM).log

$(CARDMEM).log: cardmem.sh
	@sh skipchk.sh /dev/$(USB)
	lsblk -P -o NAME|grep $(USB) | grep [1-9] && sudo partx -d /dev/$(USB)
	echo ' # partition table of image\' \
	     'label: dos\' \
	     'label-id: 0xdeadbeef\' \
	     'unit: sectors\' \
	     '\' \
	     '    2048      65535   c  *\' \
	     '   67584    4194304   L  -\' \
	     '   4261888  1048576   S  -\' \
	     '   5310464        +   L  -\' \
	    | tr '\\' '\012' | sed 's=^\ ==' | tee sfdisk.log | sudo /sbin/sfdisk -f /dev/$(USB)
	sudo partprobe -s /dev/$(USB)
	sleep 2
	lsblk -P -o NAME,PARTUUID | grep $(USB) | grep deadbeef | tail -4 > $@

mkfs: $(CARDMEM).log
	sudo mkfs.msdos -s 8 /dev/`grep deadbeef-01 $< | cut -d\" -f2`
	sudo mkfs.ext4 -F /dev/`grep deadbeef-02 $< | cut -d\" -f2`
	sudo mkswap /dev/`grep deadbeef-03 $< |cut -d\" -f2`
	sudo mkfs.ext4 -F /dev/`grep deadbeef-04 $< | cut -d\" -f2`

umount:
	@sh skipchk.sh /dev/$(USB)
	for i in `lsblk -P -o NAME,MOUNTPOINT | grep $(USB) | grep 'MOUNTPOINT="/' | cut -d\" -f4`; do umount $$i; done

loopback.img: $(BUILDROOT)
	dd if=/dev/zero of=$@ bs=2M count=1023
	sudo mkfs -t ext4 $@
	sudo mount -t ext4 -o loop $@ 

memstick: $(BITFILE).bit /dev/$(USB) umount
	sudo sh memstick.sh /dev/$(USB)
	sudo mkfs.fat /dev/$(USB)1
	sudo mkdir -p /mnt/msdos
	sudo mount -t msdos /dev/$(USB)1 /mnt/msdos
	sudo cp $< /mnt/msdos
	sudo umount /mnt/msdos

customise: $(CARDMEM).log
	sudo mount -t ext4 /dev/`grep deadbeef-02 $< | cut -d\" -f2` /mnt/deadbeef-02
	sudo chroot /mnt/deadbeef-02
	sudo umount /mnt/deadbeef-02

/proc/sys/fs/binfmt_misc/qemu-riscv64: ./qemu-riscv64
	sudo update-binfmts --import $<

debug: ../buildroot-2019.11.1-lowrisc/mainfs/host/bin/openocd /etc/udev/rules.d/52-xilinx-digilent-usb.rules
	../buildroot-2019.11.1-lowrisc/mainfs/host/bin/openocd -f openocd-nexys4ddr.cfg

/etc/udev/rules.d/52-xilinx-digilent-usb.rules:
	echo '# Rules for Digilent USB user access' > 52-xilinx-digilent-usb.rules
	echo 'ATTR{idVendor}=="1443", MODE:="666"' >> 52-xilinx-digilent-usb.rules
	echo 'ACTION=="add", ATTR{idVendor}=="0403", ATTR{manufacturer}=="Digilent", MODE:="666"' >> 52-xilinx-digilent-usb.rules
	sudo mv -f 52-xilinx-digilent-usb.rules $@
	sudo chown root:root $@
	sudo chmod 644 $@
	sudo udevadm control --reload
	sudo udevadm trigger --action=add

boot.bin:
	curl -L -O https://github.com/lowRISC/lowrisc-chip/releases/download/v0.7-rc1/$@

$(BITFILE).bit:
	curl -L -O https://github.com/lowRISC/lowrisc-chip/releases/download/v0.7-rc1/$@

clean: cleanrelease cleandisk

/dev/xyzzy:
	@echo Dummy device $@ selected. Be sure to call this Makefile with USB=your_disk_name
	@false
