# Representative gate-level simulation

This directory contains all inputs, intermediate files and results for a
representative post-fit simulation.

Quartus Prime 22.1 Standard reports Error 20268 for the selected Cyclone 10 LP
device: only a functional simulation netlist is supported. Consequently,
Quartus cannot generate `uart_top_v.sdo` for a true netlist-plus-SDF timing
simulation of this device. Use TimeQuest for timing sign-off. The functional
post-fit netlist test remains useful as a representative connectivity and
behavior check.

## Test case

At a 100 MHz system clock, the testbench configures the UART for 8-N-1 with a
divisor of 3, transmits `0xA5`, loops `stx_o` back to `srx_i` at the device
pins, and checks the line-status register and received byte through Wishbone.

## Run

The preferred entry point is the Makefile:

```sh
cd gate
make                 # regenerate the netlist and run the functional test
make functional-existing  # reuse the existing uart_top.vo
make clean
```

On WSL, the Makefile defaults to the installation under
`/mnt/f/intelFPGA_lite22.1std`. Override `INTELFPGA_ROOT`, `QUARTUS_EDA`, or
`VSIM` when the tools are installed elsewhere. When the tools are already in
`PATH`, the same targets can be selected explicitly, for example:

```sh
make QUARTUS_EDA=quartus_eda VSIM=vsim
```

The existing batch files remain available from an Intel FPGA command prompt:

```bat
cd gate
generate_netlist.bat
vsim -c -do run_functional_gate.do
```

Expected generated files in this directory include:

- `uart_top.vo` — post-fit functional Verilog netlist
- `work_functional/` — simulator compilation library
- `functional_gate_sim.log` — simulator transcript and self-check result
- `functional_gate_sim.vcd` — representative waveform

A passing run prints:

```text
POST-FIT FUNCTIONAL REPRESENTATIVE TEST PASS: received 0xa5
```
