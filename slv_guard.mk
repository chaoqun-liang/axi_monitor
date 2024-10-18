# Copyright 2024 ETH Zurich and University of Bologna.
# Licensed under the Apache License, Version 2.0, see LICENSE for details.
# SPDX-License-Identifier: Apache-2.0

# Authors:
# - Chaoqun Liang <chaoqun.liang@unibo.it>

BENDER   ?= bender
PYTHON3  ?= python3
REGTOOL  ?= $(shell $(BENDER) path register_interface)/vendor/lowrisc_opentitan/util/regtool.py
QUESTA 	 ?= questa-2023.4
TBENCH   ?= tb_slv_guard
DUT      ?= slv_guard_top

# Design and simulation variables
SLV_ROOT      ?= $(shell $(BENDER) path axi_monitor)
SLV_VSIM_DIR  := $(SLV_ROOT)/target/sim/vsim

compile_script_synth ?= $(SLV_ROOT)/target/sim/vsim/synth_compile.tcl

QUESTA_FLAGS := -permissive -suppress 3009 -suppress 8386 -error 7 +UVM_NO_RELNOTES
#QUESTA_FLAGS :=
ifdef DEBUG
	VOPT_FLAGS := $(QUESTA_FLAGS) -voptargs=+acc
	VSIM_FLAGS := $(QUESTA_FLAGS) -voptargs=+acc
	RUN_AND_EXIT := log -r /*; run -all
else
	VOPT_FLAGS := $(QUESTA_FLAGS) +acc=p+$(TBENCH). +acc=np+$(DUT).
	VSIM_FLAGS := $(QUESTA_FLAGS) -c
	RUN_AND_EXIT := run -all; exit
endif

ifeq ($(netlist_sim),1)
	NETLIST := -t netlist_sim
	VSIM_FLAGS += +notimingchecks
endif

# Download bender
bender:
	curl --proto '=https'  \
	--tlsv1.2 https://pulp-platform.github.io/bender/init -sSf | sh -s -- 0.24.0

synth_targs += -t rtl -t monitor_synth

synth-ips:
	$(BENDER) update
	$(BENDER) script synopsys \
    $(synth_targs) \
	> ${compile_script_synth}

##############
# Simulation #
##############

# Questasim
$(SLV_ROOT)/target/sim/vsim/compile.slv.tcl: Bender.yml
	$(BENDER) script vsim -t rtl -t test -t sim $(NETLIST) \
	--vlog-arg="-svinputport=compat" \
	--vlog-arg="-override_timescale 1ns/1ps" \
    --vlog-arg="+notimingchecks +nospecify" \
	--vlog-arg="-suppress 2583" > $@
	echo 'vopt $(VOPT_FLAGS) $(TBENCH) -o $(TBENCH)_opt' >> $@

slv-sim-init: $(SLV_ROOT)/target/sim/vsim/compile.slv.tcl

slv-build: slv-sim-init
	cd $(SLV_VSIM_DIR) && $(QUESTA) vsim -c -do "quit -code [source $(SLV_ROOT)/target/sim/vsim/compile.slv.tcl]"

slv-sim:
	cd $(SLV_VSIM_DIR) && $(QUESTA) vsim $(VSIM_FLAGS) -do \
		"set TESTBENCH $(TBENCH); \
		 set VSIM_FLAGS \"$(VSIM_FLAGS)\"; \
		 source $(SLV_ROOT)/target/sim/vsim/start.slv.tcl ; \
		 $(RUN_AND_EXIT)"

#################################
# Phonies #
#################################


## @section register generation
.PHONY: regen_regs

# Define the path to regtool.py
REGTOOL ?= $(REG_DIR)/vendor/lowrisc_opentitan/util/regtool.py

# Register generation targets
REGEN_TARGETS := $(SLV_ROOT)/source/registers/slv_guard_reg_pkg.sv \
                 $(SLV_ROOT)/source/registers/slv_guard_reg_top.sv \
                 $(SLV_ROOT)/sw/include/regs/slv_guard_reg.h

# Rule to generate .sv files
$(SLV_ROOT)/source/registers/slv_guard_reg_pkg.sv $(SLV_ROOT)/source/registers/slv_guard_reg_top.sv: $(SLV_ROOT)/source/registers/slv_guard_regs.hjson
	$(REGTOOL) -r -t $(SLV_ROOT)/source/registers $<

# Rule to generate .h file
$(SLV_ROOT)/sw/include/regs/slv_guard_reg.h: $(SLV_ROOT)/source/registers/slv_guard_regs.hjson
	$(REGTOOL) -D -o $@ $<

# Main target
regen_regs: $(REGEN_TARGETS)

.PHONY: slv-all slv-sim-init slv-build slv-sim 