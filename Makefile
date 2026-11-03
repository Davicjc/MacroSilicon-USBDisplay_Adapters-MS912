ms912x-y := \
	ms912x_registers.o \
	ms912x_connector.o \
	ms912x_transfer.o \
	ms912x_drv.o

obj-m := ms912x.o

KVER ?= $(shell uname -r)
KSRC ?= /lib/modules/$(KVER)/build

# Use the same compiler the kernel was built with (e.g. x86_64-linux-gnu-gcc-13
# on Ubuntu), as recorded in its .config. Falls back to the default compiler.
KCC ?= $(shell sed -n 's/^CONFIG_CC_VERSION_TEXT="\([^ ]*\) .*/\1/p' $(KSRC)/.config 2>/dev/null)
ifneq ($(KCC),)
ifneq ($(shell command -v $(KCC) 2>/dev/null),)
KBUILD_CC := CC=$(KCC)
endif
endif

all: modules

modules:
	make CHECK="/usr/bin/sparse" -C $(KSRC) M=$(CURDIR) $(KBUILD_CC) modules

clean:
	make -C $(KSRC) M=$(CURDIR) clean
	rm -f $(CURDIR)/Module.symvers $(CURDIR)/*.ur-safe
