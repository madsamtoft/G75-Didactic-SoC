# Separate entry point: never included by the Questa Makefiles.
# Full image runs publish to ../../src/tb/out_images and retain build/xsim copies.
BUILD_DIR ?= ../../build
ACC_LANG ?= sv
SIM_TOP ?= tb_student_ss
TESTCASE ?= blink
FAST_UART ?= 1
SIM_UART_MODEL ?= 1
BYPASS_UART ?= 0
SANITY_CHECK ?= 0
SIM_TIME ?= all
SIM_IMAGE ?= pattern.pgm
SIM_GENERICS ?=
# Parameter overrides may specialize XSim's root scope name; match all roots.
VCD_SCOPE ?= /*
# 1 = selected scope only; 0 = unlimited recursion.
VCD_DEPTH ?= 1

ifneq ($(strip $(VLOG_OPTS) $(VCOM_OPTS) $(VOPT_OPTS) $(VSIM_OPTS) $(DUT_LIBS) $(GUI)),)
$(error Questa compiler/library/GUI options are unsupported by XSim; use SIM_GENERICS, SIM_TIME and VCD_SCOPE instead)
endif

-include ../../fpga/local.mk
ifeq ($(OS),Windows_NT)
SHELL = cmd
VIVADO ?= vivado
PYTHON ?= python
else
SHELL = bash
VIVADO ?= bash "$(abspath ../../fpga/scripts/vivado)"
PYTHON ?= python3
endif
BUILD_DIR := $(abspath $(BUILD_DIR))
SOURCE_LIST = $(BUILD_DIR)/xsim-inputs.f

export BUILD_DIR
export FPGA_RUNTIME VIVADO_NATIVE FPGA_COLIMA_PROFILE FPGA_DOCKER_CONTEXT
export FPGA_DOCKER_IMAGE FPGA_DOCKER_INSTALL_VOLUME FPGA_DOCKER_USER_VOLUME
export FPGA_DOCKER_SETTINGS FPGA_DOCKER_MAC_ADDRESS FPGA_LICENSE_FILE

XSIM_ARGS = SOURCE_LIST "$(SOURCE_LIST)" TOP "$(SIM_TOP)" ACC_LANG "$(ACC_LANG)" BUILD_DIR "$(BUILD_DIR)" \
 TESTCASE "$(TESTCASE)" FAST_UART "$(FAST_UART)" SIM_UART_MODEL "$(SIM_UART_MODEL)" \
 BYPASS_UART "$(BYPASS_UART)" SANITY_CHECK "$(SANITY_CHECK)" TIME "$(SIM_TIME)" \
 IMAGE "$(SIM_IMAGE)" GENERICS "$(SIM_GENERICS)" VCD_SCOPE "$(VCD_SCOPE)" VCD_DEPTH "$(VCD_DEPTH)"

.PHONY: sim-vivado sim-vivado-check
sim-vivado: sources
	$(VIVADO) -mode batch -notrace -nojournal -nolog -source run.tcl -tclargs $(XSIM_ARGS)

# Resolve and validate the input manifest without compiling or simulating.
sim-vivado-check: sources
	$(VIVADO) -mode batch -notrace -nojournal -nolog -source run.tcl -tclargs $(XSIM_ARGS) CHECK_ONLY 1

# Resolve on the host, where Bender is installed; Docker mounts identical paths.
.PHONY: sources
sources:
ifeq ($(SIM_TOP),tb_didactic)
	mkdir -p "$(BUILD_DIR)"
	bender -d ../.. script flist-plus -t rtl -t vendor -t simulation -t tracer -t didactic_obi > "$(SOURCE_LIST).tmp"
	mv "$(SOURCE_LIST).tmp" "$(SOURCE_LIST)"
endif
