## Copyright 2018 Brian Swetland <swetland@frotz.net>
##
## Licensed under the Apache License, Version 2.0 
## http://www.apache.org/licenses/LICENSE-2.0

PROJECT_OBJDIR := out/-vsim-/$(PROJECT_NAME)
PROJECT_RUN := $(PROJECT_NAME)-vsim
PROJECT_BIN := out/$(PROJECT_NAME)-vsim

PROJECT_VLG_SRCS := $(filter %.v %.sv,$(PROJECT_SRCS)) 

PROJECT_OPTS := --top-module testbench
PROJECT_OPTS += --Mdir $(PROJECT_OBJDIR)
PROJECT_OPTS += --exe ../../src/testbench.cpp
PROJECT_OPTS += --cc
PROJECT_OPTS += -o ../../$(PROJECT_NAME)-vsim
PROJECT_OPTS += -DSIMULATION
PROJECT_OPTS += $(PROJECT_VOPTS)

PROJECT_OPTS += -CFLAGS -DTRACE --trace

$(PROJECT_BIN): _NAME := $(PROJECT_NAME)
$(PROJECT_BIN): _SRCS := $(PROJECT_VLG_SRCS)
$(PROJECT_BIN): _OPTS := $(PROJECT_OPTS)
$(PROJECT_BIN): _DIR := $(PROJECT_OBJDIR)

$(PROJECT_BIN): $(PROJECT_SRCS) $(PROJECT_DEF) src/testbench.cpp
	@mkdir -p $(_DIR) bin
	@echo "COMPILE (verilator): $(_NAME)"
	@$(VERILATOR) $(_OPTS) $(_SRCS)
	@echo "COMPILE (C++): $(_NAME)"
	make -C $(_DIR) -f Vtestbench.mk

$(PROJECT_NAME): $(PROJECT_BIN)

$(PROJECT_RUN): $(PROJECT_BIN)
	@$<

ALL_TARGETS += $(PROJECT_NAME) $(PROJECT_RUN) 
ALL_BUILDS += $(PROJECT_NAME)

TARGET_$(PROJECT_NAME)_DESC := build verilator sim: $(PROJECT_BIN)
TARGET_$(PROJECT_RUN)_DESC := run verilator sim: $(PROJECT_BIN)

