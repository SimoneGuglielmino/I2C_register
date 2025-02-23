PWD=$(shell pwd)
RTL_DIR = $(PWD)/../src
TOPLEVEL_LANG ?= verilog
export PYTHONPATH = $(PWD)/../
VERILOG_INCLUDE_DIRS := $(RTL_DIR)
VERILOG_SOURCES := $(RTL_DIR)/project.v
VERILOG_SOURCES += $(RTL_DIR)/top.v
VERILOG_SOURCES += $(RTL_DIR)/i2c_slave_if.v
VERILOG_SOURCES += $(RTL_DIR)/regf.v
TOPLEVEL := TT_top
MODULE := toplevel_tb
SIM_BUILD = $(PWD)/sim_build
PYUVM_LOG_LEVEL = INFO
include $(shell cocotb-config --makefiles)/Makefile.sim
