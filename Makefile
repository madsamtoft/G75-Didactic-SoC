########################################
# Top repository makefile
# Project: Edu4chip
# SoC: Didactic
#
# Description:
# * Top level commands to enable "make <command>"
# -style automated workflows.
#
# Contributors: 
# * Matti Käyrä (Matti.kayra@tuni.fi)
# * Roni Hämäläinen (roni.hamalainen@tuni.fi)
#######################################

# Common shell variables
SHELL=bash
BUILD_DIR ?= $(realpath $(CURDIR))/build/
TEST ?= blink
# Accelerator language: sv (src/rtl/pixel_acc.sv) or vhdl (src/rtl/pixel_acc_vhd.vhd)
ACC_LANG ?= sv

.PHONE: repository_init check-env clean_build clean_ips clean_all

# Fetch submodule revisions and 
# save work in submodules to stashes - avoid data loss by accidents
repository_init:
	bender update
	bender vendor init
#	git submodule update --init --recursive

check-env:
	mkdir -p "$(BUILD_DIR)"/logs/compile
	mkdir -p "$(BUILD_DIR)"/logs/opt
	mkdir -p "$(BUILD_DIR)"/logs/sim
	mkdir -p src/tb/out_images

clean_build:
	rm -rf $(BUILD_DIR)
	rm -rf  src/tb/out_images

clean_ips:
	rm -fr ./.bender

clean_all: clean_build clean_ips

######################################################################
#
######################################################################

.PHONY: soc-rtl

soc-rtl:
	echo "Generating SoC RTL. Check variables from scripts/run_kactus2_script.sh to be able to run Kactus2."
	source scripts/run_kactus2_script.sh -f scripts/kactus2_generate_soc_rtl.py

######################################################################
# hw targets
######################################################################

.PHONY: compile elaborate elaborate_fast syn syn-vivado

# compile hw library with chosen tools
compile: check-env
	$(MAKE) -C sim compile BUILD_DIR=$(BUILD_DIR) ACC_LANG=$(ACC_LANG)

# potentionally elaborate hw library with chosen tools
elaborate: check-env
	$(MAKE) -C sim elaborate BUILD_DIR=$(BUILD_DIR) TESTCASE=$(TEST)

# No signal logging for faster simulation without gui
elaborate_fast: check-env
	$(MAKE) -C sim elaborate_fast BUILD_DIR=$(BUILD_DIR) TESTCASE=$(TEST)

# Synthesis only, using the same platform-specific Vivado wrapper as make fpga.

syn: check-env
	$(MAKE) -C syn synthesize BUILD_DIR=$(BUILD_DIR) 

syn-vivado: check-env
	$(MAKE) -C fpga synth_xilinx BUILD_DIR="$(BUILD_DIR)" ACC_LANG=$(ACC_LANG)

######################################################################
# sim targets
######################################################################

.PHONY: run_sim

# compile hw library with chosen tools
run_sim: check-env
	$(MAKE) -C sim run_sim BUILD_DIR=$(BUILD_DIR)

######################################################################
# sw targets
######################################################################

.PHONY: build_test

build_test: check-env
	$(MAKE) -C sw test BUILD_DIR="$(BUILD_DIR)" TESTCASE=$(TEST)

######################################################################
# full flow targets
######################################################################

.PHONY: test_all test_all_gui test_ss test_ss_gui

test_all: check-env compile elaborate_fast build_test run_sim

test_all_gui: check-env compile elaborate build_test
	$(MAKE) -C sim run_sim BUILD_DIR=$(BUILD_DIR) GUI=""

test_ss: check-env
	$(MAKE) -C sim sim_ss BUILD_DIR=$(BUILD_DIR) ACC_LANG=$(ACC_LANG)

test_ss_gui: check-env
	$(MAKE) -C sim sim_ss BUILD_DIR=$(BUILD_DIR) ACC_LANG=$(ACC_LANG) GUI=""

######################################################################
# fpga targets
######################################################################

.PHONY: fpga vivado-check vivado-start

fpga: check-env
	$(MAKE) -C fpga all_xilinx BUILD_DIR="$(BUILD_DIR)" ACC_LANG=$(ACC_LANG)gbt66

vivado-check vivado-start:
	$(MAKE) -C fpga $@ BUILD_DIR="$(BUILD_DIR)" ACC_LANG=$(ACC_LANG)

# Independent XSim backend; existing Questa targets above remain unchanged.
XSIM_BUILD_DIR = $(if $(or $(filter /%,$(BUILD_DIR)),$(findstring :,$(BUILD_DIR))),$(BUILD_DIR),$(CURDIR)/$(BUILD_DIR))
.PHONY: sim-vivado sim-vivado-check
sim-vivado sim-vivado-check: build_test
	$(MAKE) -C sim/vivado $@ BUILD_DIR="$(XSIM_BUILD_DIR)" ACC_LANG=$(ACC_LANG) TESTCASE=$(TEST)

######################################################################
# clean files
######################################################################

.PHONY: clean
clean:
	rm -rf build/

clean-all: clean
	rm -rf .bender
	rm -rf .Xil
	rm -rf vendor_ips
	rm -f  Bender.lock