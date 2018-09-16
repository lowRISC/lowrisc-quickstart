export RISCV=$(PWD)/distrib
export PATH:=$(RISCV)/bin:$(PATH)

all: kernel tools build

kernel: linux-4.18-patched/.config
tools: distrib/STAMP.unzip
build: linux-4.18-patched/vmlinux
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
