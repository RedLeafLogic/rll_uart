# Representative post-fit simulation control

INTELFPGA_ROOT ?= /mnt/f/intelFPGA_lite22.1std

ifneq ($(wildcard $(INTELFPGA_ROOT)/quartus/bin64/quartus_eda.exe),)
QUARTUS_EDA ?= $(INTELFPGA_ROOT)/quartus/bin64/quartus_eda.exe
VSIM        ?= $(INTELFPGA_ROOT)/questa_fse/win64/vsim.exe
else
QUARTUS_EDA ?= quartus_eda
VSIM        ?= vsim
endif

PROJECT  := uart_top
REVISION := uart_top
NETLIST  := $(PROJECT).vo
SDF      := $(PROJECT)_v.sdo

.PHONY: all netlist functional functional-existing timing check-tools clean

all: functional

check-tools:
	@command -v "$(QUARTUS_EDA)" >/dev/null
	@command -v "$(VSIM)" >/dev/null

# Generate a post-fit functional netlist into this directory.
netlist: check-tools
	cd ../syn && "$(QUARTUS_EDA)" --read_settings_files=on --write_settings_files=off --simulation=on --functional=on --flatten_buses=off --timescale=1ps --tool=modelsim --format=verilog --output_directory=../gate $(PROJECT) -c $(REVISION)
	@test -f "$(NETLIST)"

# Regenerate the netlist, then run the representative loopback test.
functional: netlist
	"$(VSIM)" -c -do run_functional_gate.do

# Re-run simulation using the existing netlist without invoking Quartus.
functional-existing: check-tools
	@test -f "$(NETLIST)"
	"$(VSIM)" -c -do run_functional_gate.do

# Available only when Quartus can produce an SDF for the selected device.
timing: check-tools
	@test -f "$(NETLIST)"
	@test -f "$(SDF)"
	"$(VSIM)" -c -do run_gate.do

clean:
	$(RM) -r -- work work_functional
	$(RM) -- modelsim.ini transcript vsim.wlf gate_sim.log gate_sim.vcd functional_gate_sim.log functional_gate_sim.vcd

