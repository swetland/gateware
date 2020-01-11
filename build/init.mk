## Copyright 2018 Brian Swetland <swetland@frotz.net>
##
## Licensed under the Apache License, Version 2.0 
## http://www.apache.org/licenses/LICENSE-2.0

VERILATOR := verilator
NEXTPNR_ICE40 := nextpnr-ice40
NEXTPNR_ECP5 := nextpnr-ecp5
YOSYS := yosys
ICEPACK := icepack
ECPPACK := ecppack

VIVADOPATH := /work/xilinx/Vivado/2019.2
XSDKPATH := /work/xilinx/SDK/2019.2

VIVADO := $(VIVADOPATH)/bin/vivado
XELAB := $(VIVADOPATH)/bin/xelab
XSIM := $(VIVADOPATH)/bin/xsim
XMD := $(XSDKPATH)/bin/xmd

ALL_BUILDS :=
ALL_TARGETS :=

define project
$(eval PROJECT_DEF := $1)\
$(eval PROJECT_TYPE :=)\
$(eval PROJECT_PART :=)\
$(eval PROJECT_SRCS :=)\
$(eval PROJECT_VOPTS :=)\
$(eval PROJECT_NEXTPNR_OPTS :=)\
$(eval include $(PROJECT_DEF))\
$(eval PROJECT_NAME := $(patsubst project/%.def,%,$(PROJECT_DEF)))\
$(eval pr-inc := $(wildcard $(patsubst %,build/%.mk,$(PROJECT_TYPE))))\
$(if $(pr-inc),,$(error $1: unknown project type: "$(PROJECT_TYPE)"))\
$(eval include $(pr-inc))
endef

