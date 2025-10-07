CFLAGS ?= -W -Wall -Wextra -Werror -Wundef -Wshadow
CFLAGS += -Wdouble-promotion -fno-common -Wconversion
CFLAGS += -march=rv32imc -mabi=ilp32
CFLAGS += -Os -ffunction-sections -fdata-sections -I.
LDFLAGS ?= -Tlink.ld -nostdlib -nostartfiles -Wl,--gc-sections $(EXTRA_LINKFLAGS)
CWD ?= $(realpath $(CURDIR))
DOCKER ?= docker run -it --rm -v $(CWD):$(CWD) -w $(CWD) mdashnet/riscv
C ?= $(DOCKER) riscv-none-elf-gcc
SOURCES = startup.c hal.c main.s

build: firmware.bin

firmware.elf: $(SOURCES) hal.h link.ld Makefile
	$(C) $(CFLAGS) $(CFLAGS_EXTRA) $(SOURCES) $(LDFLAGS) -o $@

firmware.bin: firmware.elf
	./esputil/esputil mkbin firmware.elf $@

flash: firmware.bin
	./esputil/esputil flash 0 firmware.bin

monitor:
	./esputil/esputil monitor

clean:
	@rm -rf *.{bin,elf,map,lst,tgz,zip,hex} firmware*
