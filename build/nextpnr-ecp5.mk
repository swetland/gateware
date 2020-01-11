## Copyright 2020 Brian Swetland <swetland@frotz.net>
##
## Licensed under the Apache License, Version 2.0 
## http://www.apache.org/licenses/LICENSE-2.0

PROJECT_OBJDIR := out/-nextpnr-/$(PROJECT_NAME)

PROJECT_CONFIG := $(PROJECT_OBJDIR)/$(PROJECT_NAME)_out.config
PROJECT_LINT := $(PROJECT_OBJDIR)/$(PROJECT_NAME).lint
PROJECT_JSON := $(PROJECT_OBJDIR)/$(PROJECT_NAME).json
PROJECT_YS := $(PROJECT_OBJDIR)/$(PROJECT_NAME).ys
PROJECT_BIT := out/$(PROJECT_NAME).bit
PROJECT_SVF := out/$(PROJECT_NAME).svf

PROJECT_VLG_SRCS := $(filter %.v %.sv,$(PROJECT_SRCS)) 
PROJECT_LPF_SRCS := $(filter %.lpf,$(PROJECT_SRCS))

$(PROJECT_YS): _SRCS := $(PROJECT_VLG_SRCS)
$(PROJECT_YS): _JSON := $(PROJECT_JSON)
$(PROJECT_YS): $(PROJECT_SRCS) $(PROJECT_DEF) build/nextpnr-ecp5.mk
	@mkdir -p $(dir $@)
	@echo GENERATING: $@
	@echo verilog_defines -DHEX_PATHS -DYOSYS > $@
	@for src in $(_SRCS); do echo read_verilog -sv $$src; done >> $@
	@echo synth_ecp5 -top top -json $(_JSON) >> $@

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

$(PROJECT_CONFIG): _OPTS := $(PROJECT_NEXTPNR_OPTS)
$(PROJECT_CONFIG): _LPF := $(foreach lpf,$(PROJECT_LPF_SRCS),--lpf $(lpf))
$(PROJECT_CONFIG): _LOG := $(PROJECT_OBJDIR)/$(PROJECT_NAME).nextpnr.log
$(PROJECT_CONFIG): _JSON := $(PROJECT_JSON)
$(PROJECT_CONFIG): $(PROJECT_JSON) $(PROJECT_LPF_SRCS)
	@mkdir -p $(dir $@)
	@echo PLACING-AND-ROUTING: $@
	$(NEXTPNR_ECP5) --json $(_JSON) --textcfg $@ $(_OPTS) $(_LPF) 2>&1 | tee $(_LOG)

$(PROJECT_BIT): _CONFIG := $(PROJECT_CONFIG)
$(PROJECT_BIT): _BIT := $(PROJECT_BIT)
$(PROJECT_BIT): $(PROJECT_CONFIG)
	@mkdir -p $(dir $@)
	@echo GENERATING: $@
	@$(ECPPACK) $(_CONFIG) $(_BIT)

$(PROJECT_SVF): _CONFIG := $(PROJECT_CONFIG)
$(PROJECT_SVF): _SVF := $(PROJECT_SVF)
$(PROJECT_SVF): $(PROJECT_CONFIG)
	@mkdir -p $(dir $@)
	@echo GENERATING: $@
	@$(ECPPACK) --svf $(_SVF) $(_CONFIG)

$(PROJECT_NAME): $(PROJECT_BIT)

ALL_TARGETS += $(PROJECT_NAME)
ALL_BUILDS += $(PROJECT_NAME)

TARGET_$(PROJECT_NAME)_DESC := build ecp5 bitfile: $(PROJECT_BIT)

