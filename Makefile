## Copyright 2018 Brian Swetland <swetland@frotz.net>
##
## Licensed under the Apache License, Version 2.0 
## http://www.apache.org/licenses/LICENSE-2.0


#### Projects ####

include build/init.mk

help: list-all-targets

all: build-all-buildable

$(foreach p,$(wildcard project/*.def),$(call project,$p))

clean::
	rm -rf out

ALL_TARGETS := $(sort $(ALL_TARGETS)) tools cpu16-tests all
TARGET_all_DESC := build all 'build' targets
TARGET_tools_DESC := build tools: out/{a16,d16,icetool}
TARGET_cpu16-tests_DESC := run cpu16 test suite

list-all-targets::
	@true
	$(info All Possible Targets)
	$(info --------------------)
	$(foreach x,$(ALL_TARGETS),$(info $(shell printf "%-25s %s\n" "$(x)" "$(TARGET_$(x)_DESC)")))

#### Tools ####

out/a16: src/a16v5.c src/d16v5.c
	@mkdir -p out
	gcc -g -Wall -O1 -o out/a16 src/a16v5.c src/d16v5.c

out/d16: src/d16v5.c
	@mkdir -p out
	gcc -g -Wall -O1 -o out/d16 -DSTANDALONE=1 src/d16v5.c

out/udebug: src/udebug.c
	@mkdir -p out
	gcc -g -Wall -Wno-unused-result -O1 -o out/udebug src/udebug.c

out/icetool: src/icetool.c src/ftdi.c src/ftdi.h
	@mkdir -p out
	gcc -g -Wall -O1 -o out/icetool src/icetool.c src/ftdi.c -lusb-1.0 -lrt

out/crctool: src/crctool
	@mkdir -p out
	gcc -g -Wall -O1 -o out/crctool src/crctool.c

tools:: out/a16 out/d16 out/icetool out/udebug out/crctool

build-all-buildable:: $(ALL_BUILDS) tools


#### CPU16 TESTS ####

CPU16_TEST_DEPS := out/cpu16-vsim out/a16 out/d16 tests/runtest

CPU16_TESTS := $(sort $(wildcard tests/*.s))

CPU16_RESULTS := $(patsubst %.s,out/%.s.status,$(CPU16_TESTS))

out/tests/%.s.status: tests/%.s $(CPU16_TEST_DEPS)
	@./tests/runtest $<

cpu16-tests: $(CPU16_RESULTS)
	@echo ""
	@echo TESTS FAILED: `grep FAIL out/tests/*.status | wc -l`
	@echo TESTS PASSED: `grep PASS out/tests/*.status | wc -l`

