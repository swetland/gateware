## Copyright 2020 Brian Swetland <swetland@frotz.net>
##
## Licensed under the Apache License, Version 2.0 
## http://www.apache.org/licenses/LICENSE-2.0

PROJECT_OBJDIR := out/-vivado-/$(PROJECT_NAME)

PROJECT_BIT := out/$(PROJECT_NAME).bit
PROJECT_CFG := $(PROJECT_OBJDIR)/config.tcl
PROJECT_VLG_SRCS := $(filter %.v %.sv,$(PROJECT_SRCS)) 
PROJECT_XDC_SRCS := $(filter %.xdc,$(PROJECT_SRCS))

$(PROJECT_CFG): _SV := $(PROJECT_VLG_SRCS)
$(PROJECT_CFG): _XDC := $(PROJECT_XDC_SRCS)
$(PROJECT_CFG): _DIR := $(PROJECT_OBJDIR)
$(PROJECT_CFG): _PART := $(PROJECT_PART)
$(PROJECT_CFG): _NAME := $(PROJECT_NAME)
$(PROJECT_CFG): _OPTS := -I$(VIVADOPATH)/data/verilog/src/xeclib
$(PROJECT_CFG): $(PROJECT_SRCS) build/vivado.mk
	@echo "LINT (verilator): $(_NAME)"
	@$(VERILATOR) --top-module top --lint-only $(_OPTS) $(_SV) $(_V)
	@mkdir -p $(_DIR)
	@echo "# auto-generated file" > $@
	@echo "set PART {$(_PART)}" >> $@
	@echo "set BITFILE {../../$(_NAME).bit}" >> $@
	@for x in $(_SV) ; do echo "read_verilog -sv {../../../$$x}" ; done >> $@
	@for x in $(_XDC) ; do echo "read_xdc {../../../$$x}" ; done >> $@

$(PROJECT_BIT): _HEX := $(PROJECT_HEX_SRCS)
$(PROJECT_BIT): _DIR := $(PROJECT_OBJDIR)
$(PROJECT_BIT): _NAME := $(PROJECT_NAME)
$(PROJECT_BIT): $(PROJECT_HEX_SRCS) $(PROJECT_CFG)
	@echo "SYNTH (vivado): $(_NAME)"
	@mkdir -p $(_DIR)
	@rm -f $(_DIR)/log.txt
	@for hex in $(_HEX) ; do cp $$hex $(_DIR) ; done
	@(cd $(_DIR) && $(VIVADO) -mode batch -log log.txt -nojournal -source ../../../build/build-bitfile.tcl)

$(PROJECT_NAME): $(PROJECT_BIT)

ALL_TARGETS += $(PROJECT_NAME)
ALL_BUILDS += $(PROJECT_NAME)

TARGET_$(PROJECT_NAME)_DESC := build xilinx bitfile: $(PROJECT_BIT)

