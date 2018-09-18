#Vivado installs default to this address, if you used a different value, or a server
#specify the new value of XILINX_TOP in the environment
export XILINX_TOP=/opt/Xilinx
export XILINX_VIVADO=$(XILINX_TOP)/Vivado/2018.1
export TOP=$(PWD)
export RISCV=$(TOP)/distrib
export PATH:=$(RISCV)/bin:$(XILINX_VIVADO)/bin:$(XILINX_TOP)/SDK/2018.1/bin:$(XILINX_TOP)/DocNav:$(PATH)
export IP=192.168.0.51
export USB=sdc
export CARDMEM=cardmem

.SUFFIXES:

all: kernel tools build bbl

getrelease: boot.bin chip_top.bit rootfs.tar.xz
cleanrelease:
	rm -f boot.bin chip_top.bit rootfs.tar.xz
cleandisk:
	rm -f $(CARDMEM).log
partition: umount $(CARDMEM).log
kernel: linux-4.18-patched/.config
build: linux-4.18-patched/vmlinux
bbl: riscv-pk/STAMP.bbl riscv-pk/build/bbl

#The tools target downloads prebuilt executables from the firesim project.
#This may or may not suit you depending on the available download bandwidth
tools: distrib/STAMP.unzip

master.zip:
	wget https://github.com/firesim/firesim-riscv-tools-prebuilt/archive/master.zip

distrib/STAMP.unzip: master.zip
	unzip -p master.zip firesim-riscv-tools-prebuilt-master/distrib.tar.part* | tar xf -
	touch $@

linux-4.18.tar.xz:
	wget https://cdn.kernel.org/pub/linux/kernel/v4.x/linux-4.18.tar.xz

linux-4.18-patched/.config: linux-4.18.tar.xz
	tar xJf $<
	rm -rf linux-4.18-patched
	mv linux-4.18{,-patched}
	patch -d linux-4.18-patched -p1 < riscv.patch
	patch -d linux-4.18-patched -p1 < lowrisc.patch
	cp -p lowrisc_defconfig linux-4.18-patched/.config

linux-4.18-patched/vmlinux: linux-4.18-patched/.config initramfs.cpio
	make -C linux-4.18-patched ARCH=riscv -j 4 CROSS_COMPILE=riscv64-unknown-linux-gnu- CONFIG_INITRAMFS_SOURCE="../initramfs.cpio"

riscv-pk/STAMP.bbl:
	rm -rf riscv-pk
	git clone -b quickstart https://github.com/lowRISC/riscv-pk.git
	touch $@

riscv-pk/build/lowrisc.dtb: lowrisc.dts riscv-pk/STAMP.bbl linux-4.18-patched/vmlinux
	mkdir -p riscv-pk/build
	linux-4.18-patched/scripts/dtc/dtc lowrisc.dts -O dtb -o riscv-pk/build/lowrisc.dtb
	(cd riscv-pk/build; ../configure --prefix=$(RISCV) --host=riscv64-unknown-elf --with-payload=$(TOP)/linux-4.18-patched/vmlinux --enable-logo --enable-print-device-tree)

riscv-pk/build/bbl: riscv-pk/STAMP.bbl riscv-pk/build/lowrisc.dtb
	make -C riscv-pk/build bbl

lowrisc-fpga/STAMP.fpga:
	git clone -b refresh-v0.6 https://github.com/lowrisc/lowrisc-fpga.git
	make -C lowrisc-fpga/common/script
	touch $@

download: boot.bin lowrisc-fpga/STAMP.fpga
	lowrisc-fpga/common/script/recvRawEth -r -s $(IP) $<

bblupdate: riscv-pk/build/bbl
	cp riscv-pk/build/bbl boot.bin
	riscv64-unknown-linux-gnu-strip boot.bin

program-cfgmem: chip_top.bit.mcs
	vivado -mode batch -source lowrisc-fpga/common/script/program_cfgmem.tcl -tclargs "xc7a100t_0" chip_top.bit.mcs

chip_top.bit.mcs: chip_top.bit
	vivado -mode batch -source lowrisc-fpga/common/script/cfgmem.tcl -tclargs "xc7a100t_0" chip_top.bit

fatdisk: $(CARDMEM).log boot.bin
	sudo mkdir -p /mnt/deadbeef-01
	sudo mount /dev/`grep deadbeef-01 $< | cut -d\" -f2` /mnt/deadbeef-01
	sudo cp boot.bin /mnt/deadbeef-01
	sudo umount /mnt/deadbeef-01

extdisk: $(CARDMEM).log rootfs.tar.xz
	sudo mkdir -p /mnt/deadbeef-02
	sudo mount -t ext4 /dev/`grep deadbeef-02 $< | cut -d\" -f2` /mnt/deadbeef-02
	sudo tar xJf rootfs.tar.xz -C /mnt/deadbeef-02
	sudo umount /mnt/deadbeef-02

$(CARDMEM).log: cardmem.sh
	-sudo partx -d /dev/$(USB)
	sudo sh cardmem.sh /dev/$(USB)
	sleep 2
	lsblk -P -o NAME,PARTUUID | grep $(USB) | grep deadbeef | tail -4 > $@

mkfs: $(CARDMEM).log
	sudo mkfs -t msdos /dev/`grep deadbeef-01 $< | cut -d\" -f2`
	sudo mkfs -t ext4 /dev/`grep deadbeef-02 $< | cut -d\" -f2`
	sudo mkswap /dev/`grep deadbeef-03 $< |cut -d\" -f2`
	sudo mkfs -t ext4 /dev/`grep deadbeef-04 $< | cut -d\" -f2`

umount:
	for i in `lsblk -P -o NAME,MOUNTPOINT |grep $(USB) | grep 'MOUNTPOINT="/' | cut -d\" -f4`; do umount $$i; done
	sudo partx -d /dev/$(USB)

#These targets are for generating prebuild filing system images
#They are deprecated because writing to a real disk will be slower than direct creation
sdcard.img: rootfs.tar.xz
	dd if=/dev/zero of=$@ bs=2M count=2047
	sh cardmem.sh $@
	-sudo partx -a $@
	sleep 2
	lsblk -P -o NAME,PARTUUID | grep deadbeef | tail -4 > $@.log
	make mkfs fatdisk extdisk CARDMEM=$@

loopback.img: rootfs.tar.xz
	dd if=/dev/zero of=$@ bs=2M count=1023
	sudo mkfs -t ext4 $@
	sudo mount -t ext4 -o loop $@ 

boot.bin:
	curl -L https://github.com/lowRISC/lowrisc-chip/releases/download/v0.6-rc3/$@ > $@

chip_top.bit:
	curl -L https://github.com/lowRISC/lowrisc-chip/releases/download/v0.6-rc3/$@ > $@

rootfs.tar.xz:
	curl -L https://github.com/lowRISC/lowrisc-chip/releases/download/v0.6-rc3/$@ > $@

