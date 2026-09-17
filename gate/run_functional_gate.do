onerror {quit -code 1 -force}
transcript file functional_gate_sim.log

if {![file exists uart_top.vo]} {
    echo "ERROR: gate/uart_top.vo is missing. Run generate_netlist.bat first."
    quit -code 2 -force
}

if {[file exists work_functional]} {
    vdel -lib work_functional -all
}
vlib work_functional
vmap work work_functional

vlog -work work -timescale 1ps/1ps ../lib/intelFPGA_lite22.1std/220model.v
vlog -work work -timescale 1ps/1ps ../lib/intelFPGA_lite22.1std/altera_primitives.v
vlog -work work -timescale 1ps/1ps ../lib/intelFPGA_lite22.1std/altera_mf.v
vlog -work work -timescale 1ps/1ps ../lib/intelFPGA_lite22.1std/cyclone10lp_atoms.v
vlog -work work -timescale 1ps/1ps uart_top.vo
vlog -sv -work work -timescale 1ns/1ps tb_uart_gate.sv

vsim -t 1ps work.tb_uart_gate
log -r /*
vcd file functional_gate_sim.vcd
vcd add -r /tb_uart_gate/*
run -all
vcd flush
quit -code 0 -force
