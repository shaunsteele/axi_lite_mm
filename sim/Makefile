# CocoTB Makefile

REPO_DIR := /home/shaun/repos/axi4_lite_2_mem

IF_DIR	:= $(REPO_DIR)/interfaces
RTL_DIR := $(REPO_DIR)/rtl
SIM_DIR := $(REPO_DIR)/sim

SIM ?= verilator

# EXTRA_ARGS += --timing
# EXTRA_ARGS += --coverage
EXTRA_ARGS += --trace --trace-structs

TOPLEVELLANG ?= verilog

VERILOG_SOURCES += $(IF_DIR)/mem_if.sv
VERILOG_SOURCES += $(IF_DIR)/axi4_lite_if.sv
VERILOG_SOURCES += $(RTL_DIR)/axi4_lite_2_mem.sv
VERILOG_SOURCES += $(SIM_DIR)/tb_axi4_lite_2_mem_top.sv

TOPLEVEL = tb_axi4_lite_2_mem_top

MODULE = tb_axi4_lite_2_mem

include $(shell cocotb-config --makefiles)/Makefile.sim

WAVES = dump.vcd

.PHONY: waves
waves:
	gtkwave $(WAVES)

# .PHONY: clean
# clean:
# 	rm -rf __pycache__/
