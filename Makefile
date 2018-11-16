
SRCS := hdl/testbench.sv
SRCS += hdl/simram.sv
SRCS += hdl/cpu/cpu.v hdl/cpu/alu.v hdl/cpu/regfile.v

VERILATOR := /work/verilator/bin/verilator

VOPTS := --top-module testbench --Mdir out --exe ../src/testbench.cpp --cc -CFLAGS -DTRACE --trace

all: out/Vtestbench out/a16 out/d16 out/icetool

out/Vtestbench: $(SRCS) src/testbench.cpp
	@mkdir -p out
	@$(VERILATOR) $(VOPTS) $(SRCS)
	@make -C out -f Vtestbench.mk

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

