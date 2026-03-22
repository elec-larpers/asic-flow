.PHONY: help shell sim flow flow-emergency view view-odb odb ods view-stdcell-gds all mem-init-check sram-feasibility production-check clean-runs clean-sim clean

NIX_DEVELOP := nix develop -c bash -lc
HANDOFF_DIR := ../ModelToRTL/librelane_handoff
LATEST_RUN := $(lastword $(sort $(wildcard runs/RUN_*)))
LATEST_FINAL_ODB := $(firstword $(wildcard $(LATEST_RUN)/53-odb-cellfrequencytables/*.odb))
LATEST_ANY_ODB := $(lastword $(sort $(wildcard $(LATEST_RUN)/*/*.odb)))
CURRENT_ODB ?= $(or $(LATEST_FINAL_ODB),$(LATEST_ANY_ODB))
SKY130_ROOT := /home/george-sleen/.ciel/ciel/sky130/versions/0fe599b2afb6708d281543108caf8310912f54af
SKY130_STDCELL_GDS := $(SKY130_ROOT)/sky130A/libs.ref/sky130_fd_sc_hd/gds/sky130_fd_sc_hd.gds
SKY130_MAGICRC := $(SKY130_ROOT)/sky130A/libs.tech/magic/sky130A.magicrc
STDCELL_DEFAULT_CELL := sky130_fd_sc_hd__inv_1

help:
	@printf '%s\n' \
		'ASIC Flow Make Targets' \
		'' \
		'General:' \
		'  make help' \
		'    Print this command reference.' \
		'  make shell' \
		'    Print the command to enter the Nix dev shell manually.' \
		'' \
		'Simulation and Flow:' \
		'  make sim' \
		'    Run the handoff top-level simulation script in $(HANDOFF_DIR).' \
		'  make flow' \
		'    Run LibreLane on the current config.json.' \
		'    Important: config.json currently points at the emergency placeholder top in ./rtl,' \
		'    not the full YOLO-generated implementation.' \
		'  make flow-emergency' \
		'    Alias for make flow.' \
		'  make all' \
		'    Run make sim, then make flow.' \
		'' \
		'Inspection / Viewing:' \
		'  make view ods' \
		'    Alias for make view-odb.' \
		'  make view-odb' \
		'    Open the newest available ODB snapshot from the latest LibreLane run in the OpenROAD GUI.' \
		'    Current file: $(CURRENT_ODB)' \
		'  make view-stdcell-gds' \
		'    Open the Sky130 standard-cell library GDS in Magic.' \
		'    Loads $(STDCELL_DEFAULT_CELL) by default so the view is not blank.' \
		'    This shows real polygon/transistor geometry for the library cells, not your full chip.' \
		'' \
		'Blocker Analysis:' \
		'  make mem-init-check' \
		'    Check that generated MEMORY_INIT_file references resolve in the RTL handoff.' \
		'  make sram-feasibility' \
		'    Estimate how many local Sky130 SRAM macros would be needed for the YOLO top.' \
		'  make production-check' \
		'    Run both blocker checks above.' \
		'' \
		'Cleanup:' \
		'  make clean-sim' \
		'    Remove simulation outputs under $(HANDOFF_DIR)/out.' \
		'  make clean-runs' \
		'    Remove LibreLane runs/ output.' \
		'  make clean' \
		'    Remove both simulation and LibreLane generated output.'

shell:
	@printf '%s\n' 'nix develop --accept-flake-config'

sim:
	$(NIX_DEVELOP) 'bash $(HANDOFF_DIR)/run_top_sim.sh'

flow:
	$(NIX_DEVELOP) 'librelane --design-dir . --pdk sky130A config.json'

flow-emergency: flow

view:
	@:

odb ods: view-odb

view-odb:
	$(NIX_DEVELOP) 'CURRENT_ODB=$(CURRENT_ODB) openroad -gui tools/view_odb.tcl'

view-stdcell-gds:
	$(NIX_DEVELOP) 'PDK_ROOT=$(SKY130_ROOT) SKY130_MAGICRC=$(SKY130_MAGICRC) STDCELL_GDS=$(SKY130_STDCELL_GDS) STDCELL_DEFAULT_CELL=$(STDCELL_DEFAULT_CELL) magic -rcfile tools/view_stdcell_gds.magicrc'

all: sim flow

mem-init-check:
	$(NIX_DEVELOP) './tools/check_mem_init_refs.py'

sram-feasibility:
	$(NIX_DEVELOP) './tools/analyze_memory_plan.py'

production-check: mem-init-check sram-feasibility

clean-sim:
	rm -rf $(HANDOFF_DIR)/out

clean-runs:
	rm -rf runs

clean: clean-sim clean-runs
