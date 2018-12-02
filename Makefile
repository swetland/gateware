
#CPU_SRCS := hdl/cpu/cpu.v hdl/cpu/alu.v hdl/cpu/regfile.v
CPU_SRCS := hdl/cpu16.sv hdl/cpu16_regs.sv hdl/cpu16_alu.sv

VGA_SRCS := hdl/vga/vga40x30x2.v hdl/vga/vga.v hdl/vga/videoram.v hdl/vga/chardata.v

VSIM_CPU_SRCS := hdl/testbench.sv hdl/simram.sv $(CPU_SRCS)

VSIM_VGA_SRCS := hdl/testvga.sv $(VGA_SRCS)

ICE40_SRCS := hdl/ice40.v hdl/spi_debug_ifc.v hdl/lattice/pll_12_25.v
ICE40_SRCS += $(CPU_SRCS) $(VGA_SRCS)

USE_NEXTPNR ?= true

VERILATOR := verilator
ARACHNEPNR := arachne-pnr
NEXTPNR := nextpnr-ice40
YOSYS := yosys
ICEPACK := icepack

VOPTS_CPU := --top-module testbench --Mdir out/cpu
VOPTS_CPU += --exe ../src/testbench.cpp --cc -CFLAGS -DTRACE --trace

VOPTS_VGA := --top-module testbench --Mdir out/vga
VOPTS_VGA += --exe ../src/testbench.cpp --cc -CFLAGS -DTRACE -CFLAGS -DVGA --trace

all: out/cpu/Vtestbench out/ice40.bin out/a16 out/d16 out/icetool

vga: out/vga/Vtestbench

out/cpu/Vtestbench: $(VSIM_CPU_SRCS) src/testbench.cpp
	@mkdir -p out/cpu
	@$(VERILATOR) $(VOPTS_CPU) $(VSIM_CPU_SRCS)
	@make -C out/cpu -f Vtestbench.mk

out/vga/Vtestbench: $(VSIM_VGA_SRCS) src/testbench.cpp
	@mkdir -p out/vga
	@$(VERILATOR) $(VOPTS_VGA) $(VSIM_VGA_SRCS)
	@make -C out/vga -f Vtestbench.mk

out/ice40.bin: out/ice40.asc
	@mkdir -p out
	$(ICEPACK) $< $@

out/ice40.lint: $(ICE40_SRCS)
	@mkdir -p out
	$(VERILATOR) --top-module top --lint-only $(ICE40_SRCS)
	@touch out/ice40.lint

out/ice40.ys: $(ICE40_SRCS) Makefile
	@mkdir -p out
	@echo generating $@
	@echo verilog_defines -DHEX_PATHS -DYOSYS > $@
	@for src in $(ICE40_SRCS) ; do echo read_verilog -sv $$src ; done >> $@
	@echo synth_ice40 -top top -blif out/ice40.blif -json out/ice40.json >> $@

ifeq ($(USE_NEXTPNR), true)
out/ice40.json: out/ice40.ys out/ice40.lint
	@mkdir -p out
	$(YOSYS) -s out/ice40.ys 2>&1 | tee out/ice40.synth.log

out/ice40.asc: out/ice40.json
	@mkdir -p out
	$(NEXTPNR) --package sg48 --up5k --pcf hdl/ice40up.pcf --asc out/ice40.asc --json out/ice40.json 2>&1 | tee out/ice40.pnr.log
else
out/ice40.blif: out/ice40.ys out/ice40.lint
	@mkdir -p out
	$(YOSYS) -s out/ice40.ys 2>&1 | tee out/ice40.synth.log

out/ice40.asc: out/ice40.blif
	@mkdir -p out
	$(ARACHNEPNR) -d 5k -p sg48 -o out/ice40.asc -p hdl/ice40up.pcf out/ice40.blif 2>&1 | tee out/ice40.pnr.log
endif

run: out/cpu/Vtestbench out/test16.hex
	./out/cpu/Vtestbench -trace out/trace.vcd -dump out/memory.bin -load out/test16.hex

out/test16.hex: src/test16.s out/a16 out/d16
	out/a16 src/test16.s out/test16.hex

#out/test.hex: test.hex
#	cp test.hex out/test.hex

out/a16: src/a16v5.c src/d16v5.c
	@mkdir -p out
	gcc -g -Wall -O1 -o out/a16 src/a16v5.c src/d16v5.c

out/d16: src/d16v5.c
	@mkdir -p out
	gcc -g -Wall -O1 -o out/d16 -DSTANDALONE=1 src/d16v5.c

out/icetool: src/icetool.c src/ftdi.c src/ftdi.h
	@mkdir -p out
	gcc -g -Wall -O1 -o out/icetool src/icetool.c src/ftdi.c -lusb-1.0 -lrt

TEST_DEPS := out/cpu/Vtestbench out/a16 out/d16 tests/runtest

TESTS := $(sort $(wildcard tests/*.s))

RESULTS := $(patsubst %.s,out/%.s.status,$(TESTS))

out/tests/%.s.status: tests/%.s $(TEST_DEPS)
	@./tests/runtest $<

test: $(RESULTS)
	@echo ""
	@echo TESTS FAILED: `grep FAIL out/tests/*.status | wc -l`
	@echo TESTS PASSED: `grep PASS out/tests/*.status | wc -l`

clean:
	rm -rf out/

