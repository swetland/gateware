## Copyright 2018 Brian Swetland <swetland@frotz.net>
##
## Licensed under the Apache License, Version 2.0 
## http://www.apache.org/licenses/LICENSE-2.0

PROJECT_OBJDIR := out/-nextpnr-/$(PROJECT_NAME)

PROJECT_BIN := out/$(PROJECT_NAME).bin
PROJECT_ASC := $(PROJECT_OBJDIR)/$(PROJECT_NAME).asc
PROJECT_LINT := $(PROJECT_OBJDIR)/$(PROJECT_NAME).lint
PROJECT_JSON := $(PROJECT_OBJDIR)/$(PROJECT_NAME).json
PROJECT_YS := $(PROJECT_OBJDIR)/$(PROJECT_NAME).ys

PROJECT_VLG_SRCS := $(filter %.v %.sv,$(PROJECT_SRCS)) 
PROJECT_PCF_SRCS := $(filter %.pcf,$(PROJECT_SRCS))

$(PROJECT_YS): _SRCS := $(PROJECT_VLG_SRCS)
$(PROJECT_YS): _JSON := $(PROJECT_JSON)
$(PROJECT_YS): $(PROJECT_SRCS) $(PROJECT_DEF) build/nextpnr-ice40.mk
	@mkdir -p $(dir $@)
	@echo GENERATING: $@
	@echo verilog_defines -DHEX_PATHS -DYOSYS > $@
	@for src in $(_SRCS); do echo read_verilog -sv $$src; done >> $@
	@echo synth_ice40 -top top -json $(_JSON) >> $@

$(PROJECT_LINT): _SRCS := $(PROJECT_VLG_SRCS)
$(PROJECT_LINT): $(PROJECT_SRCS)
	@mkdir -p $(dir $@)
	@echo LINTING: $@
	@$(VERILATOR) --top-module top --lint-only $(_SRCS)
	@touch $@

$(PROJECT_JSON): _LOG := $(PROJECT_OBJDIR)/$(PROJECT_NAME).yosys.log
$(PROJECT_JSON): $(PROJECT_YS) $(PROJECT_LINT)
	@mkdir -p $(dir $@)
	@echo SYNTHESIZING: $@
	@$(YOSYS) -s $< 2>&1 | tee $(_LOG)

$(PROJECT_ASC): _OPTS := $(PROJECT_NEXTPNR_OPTS)
$(PROJECT_ASC): _PCF := $(foreach pcf,$(PROJECT_PCF_SRCS),--pcf $(pcf))
$(PROJECT_ASC): _LOG := $(PROJECT_OBJDIR)/$(PROJECT_NAME).nextpnr.log
$(PROJECT_ASC): $(PROJECT_JSON) $(PROJECT_PCF_SRCS)
	@mkdir -p $(dir $@)
	@echo PLACING-AND-ROUTING: $@
	@$(NEXTPNR_ICE40) --asc $@ --json $< $(_PCF) $(_OPTS) 2>&1 | tee $(_LOG)

$(PROJECT_BIN): $(PROJECT_ASC)
	@mkdir -p $(dir $@)
	@echo PACKING: $@
	@$(ICEPACK) $< $@

$(PROJECT_NAME): $(PROJECT_BIN)

ALL_TARGETS += $(PROJECT_NAME)
ALL_BUILDS += $(PROJECT_NAME)

TARGET_$(PROJECT_NAME)_DESC := build ice40 bitfile: $(PROJECT_BIN)

