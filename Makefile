export TOP=$(PWD)
export RISCV=$(TOP)/distrib
export PATH:=$(RISCV)/bin:$(PATH)

all: kernel tools build

kernel: linux-4.18-patched/.config
tools: distrib/STAMP.unzip
build: linux-4.18-patched/vmlinux
bbl: riscv-pk/STAMP.bbl riscv-pk/build/bbl

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

linux-4.18-patched/vmlinux: linux-4.18-patched/.config
	make -C linux-4.18-patched ARCH=riscv -j 4 CROSS_COMPILE=riscv64-unknown-linux-gnu- CONFIG_INITRAMFS_SOURCE="../initramfs.cpio"

riscv-pk/STAMP.bbl: linux-4.18-patched/vmlinux
	git clone -b quickstart https://github.com/lowRISC/riscv-pk.git
	mkdir -p riscv-pk/build
	linux-4.18-patched/scripts/dtc/dtc lowrisc.dts -O dtb -o riscv-pk/build/lowrisc.dtb
	(cd riscv-pk/build; ../configure --prefix=$(RISCV) --host=riscv64-unknown-elf --with-payload=$(TOP)/linux-4.18-patched/vmlinux --enable-logo --enable-print-device-tree)
	touch $@

riscv-pk/build/bbl: riscv-pk/STAMP.bbl 
	make -C riscv-pk/build bbl

lowrisc-fpga/STAMP.fpga:
	git clone -b refresh-v0.6 https://github.com/lowrisc/lowrisc-fpga.git
	make -C lowrisc-fpga/common/script
	touch $@

download: lowrisc-fpga/STAMP.fpga riscv-pk/build/bbl
	lowrisc-fpga/common/script/recvRawEth -r -s 192.168.0.51 riscv-pk/build/bbl
