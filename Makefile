#Vivado installs default to this address, if you used a different value, or a server
#specify the new value of XILINX_TOP in the environment
export XILINX_TOP=/opt/Xilinx
export XILINX_VIVADO=$(XILINX_TOP)/Vivado/2018.1
export TOP=$(PWD)
export RISCV=$(TOP)/distrib
export PATH:=$(RISCV)/bin:$(XILINX_VIVADO)/bin:$(XILINX_TOP)/SDK/2018.1/bin:$(XILINX_TOP)/DocNav:$(PATH)
export IP=192.168.0.51

all: kernel tools build bbl

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
	lowrisc-fpga/common/script/recvRawEth -r -s $(IP) riscv-pk/build/bbl

program-cfgmem: chip_top.bit.mcs
	vivado -mode batch -source lowrisc-fpga/common/script/program_cfgmem.tcl -tclargs "xc7a100t_0" chip_top.bit.mcs

chip_top.bit.mcs: chip_top.bit
	vivado -mode batch -source lowrisc-fpga/common/script/cfgmem.tcl -tclargs "xc7a100t_0" chip_top.bit

chip_top.bit:
	curl -L https://github.com/lowRISC/lowrisc-chip/releases/download/v0.6-rc1/chip_top.bit > $@
