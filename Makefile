
CPU_SRCS := hdl/cpu/cpu.v hdl/cpu/alu.v hdl/cpu/regfile.v

VGA_SRCS := hdl/vga/vga40x30x2.v hdl/vga/vga.v hdl/vga/videoram.v hdl/vga/chardata.v

VSIM_SRCS := hdl/testbench.sv hdl/simram.sv $(CPU_SRCS)

ICE40_SRCS := hdl/ice40.v hdl/spi_debug_ifc.v hdl/lattice/pll_12_25.v
ICE40_SRCS += $(CPU_SRCS) $(VGA_SRCS)

VERILATOR := verilator
ARACHNEPNR := arachne-pnr
YOSYS := yosys
ICEPACK := icepack

VOPTS := --top-module testbench --Mdir out --exe ../src/testbench.cpp --cc -CFLAGS -DTRACE --trace

all: out/Vtestbench out/ice40.bin out/a16 out/d16 out/icetool

out/Vtestbench: $(VSIM_SRCS) src/testbench.cpp
	@mkdir -p out
	@$(VERILATOR) $(VOPTS) $(VSIM_SRCS)
	@make -C out -f Vtestbench.mk

out/ice40.bin: out/ice40.asc
	@mkdir -p out
	$(ICEPACK) $< $@

out/ice40.lint: $(ICE40_SRCS)
	@mkdir -p out
	$(VERILATOR) --top-module top --lint-only $(ICE40_SRCS)

out/ice40.blif: $(ICE40_SRCS) out/ice40.lint
	@mkdir -p out
	$(YOSYS) -p 'synth_ice40 -top top -blif out/ice40.blif' $(ICE40_SRCS) 2>&1 | tee out/ice40.synth.log

out/ice40.asc: out/ice40.blif
	@mkdir -p out
	$(ARACHNEPNR) -d 5k -p sg48 -o out/ice40.asc -p hdl/ice40up.pcf out/ice40.blif 2>&1 | tee out/ice40.pnr.log

run: out/Vtestbench out/test.hex
	./out/Vtestbench -trace out/trace.vcd -dump out/memory.bin -load out/test.hex

out/test.hex: src/test.s out/a16 out/d16
	out/a16 src/test.s out/test.hex

#out/test.hex: test.hex
#	cp test.hex out/test.hex

out/a16: src/a16.c src/d16.c
	@mkdir -p out
	gcc -g -Wall -O1 -o out/a16 src/a16.c src/d16.c

out/d16: src/d16.c
	@mkdir -p out
	gcc -g -Wall -O1 -o out/d16 -DSTANDALONE=1 src/d16.c

out/icetool: src/icetool.c src/ftdi.c src/ftdi.h
	@mkdir -p out
	gcc -g -Wall -O1 -o out/icetool src/icetool.c src/ftdi.c -lusb-1.0 -lrt

TEST_DEPS := out/Vtestbench out/a16 out/d16 tests/runtest

TESTS := $(wildcard tests/*.s)

RESULTS := $(patsubst %.s,out/%.s.status,$(TESTS))

out/tests/%.s.status: tests/%.s $(TEST_DEPS)
	@./tests/runtest $<

test: $(RESULTS)
	@echo ""
	@echo TESTS FAILED: `grep FAIL out/tests/*.status | wc -l`
	@echo TESTS PASSED: `grep PASS out/tests/*.status | wc -l`

clean:
	rm -rf out/

