
SRCS := hdl/testbench.sv
SRCS += hdl/simram.sv
SRCS += hdl/cpu/cpu.v hdl/cpu/alu.v hdl/cpu/flags.v hdl/cpu/regfile.v

VERILATOR := VERILATOR_ROOT=/work/verilator /work/verilator/bin/verilator

VOPTS := --top-module testbench --Mdir out --exe ../src/testbench.cpp --cc -CFLAGS -DTRACE --trace

all: out/Vtestbench out/a16

out/Vtestbench: $(SRCS) src/testbench.cpp
	@mkdir -p out
	@$(VERILATOR) $(VOPTS) $(SRCS)
	@make -C out -f Vtestbench.mk

run: out/Vtestbench out/test.hex
	./out/Vtestbench -trace out/trace.vcd -dump out/memory.bin -load out/test.hex

out/test.hex: src/test.s out/a16
	out/a16 src/test.s out/test.hex

#out/test.hex: test.hex
#	cp test.hex out/test.hex

out/a16: src/a16.c src/d16.c
	@mkdir -p out
	gcc -Wall -O1 -o out/a16 src/a16.c src/d16.c

out/d16: src/d16.c
	@mkdir -p out
	gcc -Wall -O1 -o out/d16 -DSTANDALONE=1 src/d16.c

clean:
	rm -rf out/

