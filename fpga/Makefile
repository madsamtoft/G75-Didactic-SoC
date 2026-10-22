######################################
# Didactic SoC 
# FPGA flow makefile
# Contributor(s):
#   -Matti Käyrä (matti.kayra@tuni.fi)
######################################

SHELL = bash
# Optional machine-local overrides; the wrapper owns platform selection.
-include local.mk
VIVADO ?= bash "$(CURDIR)/scripts/vivado"
export FPGA_RUNTIME VIVADO_NATIVE FPGA_COLIMA_PROFILE FPGA_DOCKER_CONTEXT
export FPGA_DOCKER_IMAGE FPGA_DOCKER_INSTALL_VOLUME FPGA_DOCKER_USER_VOLUME
export FPGA_DOCKER_SETTINGS FPGA_DOCKER_MAC_ADDRESS FPGA_LICENSE_FILE

export TEST ?= pixel_inversion

export BUILD_DIR ?= ../build
export PROJECT ?= nexys_a7
# Accelerator language (sv | vhdl), read by scripts/run_xilinx.tcl
export ACC_LANG ?= sv

check_env:
	mkdir -p "$(BUILD_DIR)"

.PHONY: vivado-check vivado-start
vivado-check: check_env
	$(VIVADO) -mode batch -notrace -nojournal -log "$(BUILD_DIR)/vivado-check.log" -source scripts/check_vivado.tcl

vivado-start:
	bash scripts/colima-start

# ============================================================
# File-list generation (file lists included in repo)
# Requires: bender on PATH
# ============================================================
gen_flist:
	ROOT=$$(realpath ..); \
	bender script flist -t fpga -t xilinx -t rtl -t vendor -t synthesis -t didactic_obi | \
	sed "s|$$ROOT/|../|g" > flist.f; \
	bender script flist -t fpga -t xilinx -t rtl -t vendor -t synthesis -t didactic_obi -t bscane | \
	sed "s|$$ROOT/|../|g" > flist_bscane.f

# gen_includes: relative paths - commit the result, works on Windows Vivado too
gen_includes:
	ROOT=$$(realpath ..); \
	{ for dep in common_cells axi apb obi register_interface; do \
	    path=$$(bender path $$dep); echo "../$${path#$$ROOT/}/include"; \
	  done; \
	  echo "../vendor_ips/ibex/vendor/lowrisc_ip/dv/sv/dv_utils"; \
	  echo "../vendor_ips/ibex/vendor/lowrisc_ip/ip/prim/rtl"; \
	  echo "../vendor_ips/ibex/rtl"; \
	} > includes.f

gen_filelists: gen_flist gen_includes

.PHONY: synth_xilinx all_xilinx all_xilinx_gui
synth_xilinx: check_env
	$(VIVADO) -mode batch -notrace -source scripts/run_xilinx.tcl -tclargs synth

all_xilinx: check_env
	$(VIVADO) -mode batch -notrace -source scripts/run_xilinx.tcl

all_xilinx_gui: check_env
	$(VIVADO) -mode gui -source scripts/run_xilinx.tcl &

# Build software
build_test: check_env
	$(MAKE) -C sw test BUILD_DIR="$(abspath $(BUILD_DIR))/fpga" TESTCASE=$(TEST)

# Launch GDB and upload
load_elf: check_env
	gdb-multiarch $(BUILD_DIR)/fpga/sw/$(TEST).elf -x ../fpga/utils/connect-and-load.gdb
