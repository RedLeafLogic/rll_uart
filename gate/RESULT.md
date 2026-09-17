# Gate simulation result

Date: 2026-09-17  
Device: Cyclone 10 LP (`10CL006YU256C6G`)  
Quartus Prime: 22.1std.1 Build 917  
Simulator: Questa Intel Starter FPGA Edition 2021.2

## Requested netlist plus SDF simulation

Not supported for this device/tool combination. Quartus EDA Netlist Writer
returned:

```text
Error (20268): Functional simulation is off but it is the only supported
netlist type for this device.
```

No `.sdo`/SDF file was generated. Timing sign-off must therefore use the
TimeQuest results in `syn/uart_top.sta.rpt`.

The current TimeQuest report passes the 100 MHz constraint. At the slow
1200 mV, 85 C corner it reports setup slack `+1.793 ns`, hold slack
`+0.355 ns`, TNS `0.000 ns`, and restricted Fmax `121.85 MHz`.

## Representative post-fit functional simulation

Result: **PASS**

The test ran at 100 MHz and performed the following operations through the
post-fit `uart_top.vo` netlist:

1. Released reset.
2. Configured UART for 8 data bits, no parity and 1 stop bit.
3. Programmed divisor 3.
4. Transmitted `0xA5` through a pin-level `stx_o` to `srx_i` loopback.
5. Polled the line-status register for RX data-ready and checked RX errors.
6. Read the receive buffer and compared it with `0xA5`.

Final simulator result:

```text
POST-FIT FUNCTIONAL REPRESENTATIVE TEST PASS: received 0xa5 at 6430.000 ns
Errors: 0, Warnings: 0
```

Primary artifacts:

- `tb_uart_gate.sv`
- `uart_top.vo`
- `functional_gate_sim.log`
- `functional_gate_sim.vcd`
- `vsim.wlf`
- `work_functional/`
