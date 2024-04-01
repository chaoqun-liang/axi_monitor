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
SLV_ROOT      ?= $(shell $(BENDER) path slv_guard)
SLV_VSIM_DIR  := $(SLV_ROOT)/target/sim/vsim

QUESTA_FLAGS := -permissive -suppress 3009 -suppress 8386 -error 7 +UVM_NO_RELNOTES
#QUESTA_FLAGS :=
ifdef DEBUG
	VOPT_FLAGS := $(QUESTA_FLAGS) +acc
	VSIM_FLAGS := $(QUESTA_FLAGS) +acc
	RUN_AND_EXIT := log -r /*; run -all
else
	VOPT_FLAGS := $(QUESTA_FLAGS) +acc=p+$(TBENCH). +acc=np+$(DUT).
	VSIM_FLAGS := $(QUESTA_FLAGS) -c
	RUN_AND_EXIT := run -all; exit
endif


##############
# Simulation #
##############

# Questasim
$(SLV_ROOT)/target/sim/vsim/compile.slv.tcl: Bender.yml
	$(BENDER) script vsim -t rtl -t test -t sim \
	--vlog-arg="-svinputport=compat" \
	--vlog-arg="-override_timescale 1ns/1ps" \
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
# Phonies (KEEP AT END OF FILE) #
#################################

.PHONY: slv-all slv-sim-init slv-build slv-sim 
