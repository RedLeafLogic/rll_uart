# rll_uart

English | [日本語](README.md)

`rll_uart` is a 16550-style UART IP core written in SystemVerilog. It provides
a 32-bit Wishbone interface, transmit and receive FIFOs, interrupts, modem
control signals, and internal loopback.

> [!NOTE]
> This is a revised version of RTL originally released in 2010 as a
> SystemVerilog coding example, updated with GPT-6 Astra. Astra performed static
> analysis and helped fix the design, including adding the 5-bit and 6-bit modes
> that were not supported in the 2010 version.
> The core implements the main 16550 features, but it does not claim complete
> compatibility. Verify the register behavior and timing required by the target
> system before integration.

## Features

- SystemVerilog RTL
- 32-bit Wishbone bus interface
- 5- to 8-bit character lengths, parity, stop-bit, and break control
- 16-entry transmit and receive FIFOs
- Receive, transmit, line-status, and modem-status interrupts
- RTS, CTS, DTR, DSR, RI, and DCD modem signals
- Internal loopback
- Byte-spaced and 32-bit-word-spaced register layouts

## Register layout

Define one of the following configurations at build time.

| Define | Layout | Data lane |
| --- | --- | --- |
| `ALIGN_1B` | Registers at one-byte intervals | Byte lane selected by the address |
| `ALIGN_4B` | Registers at four-byte intervals | Least-significant 8 bits |

See the [register structure](doc/register_structure.md),
[UART state machines](doc/uart_state_machines.md), and
[module structure](doc/module_structure.md) for design details.

## Repository layout

| Path | Contents |
| --- | --- |
| `rtl/` | UART core, FIFOs, packages, and interfaces |
| `bench/` | Synthesis top level and verification wrappers |
| `sim/` | Testbenches and file lists for Verilator and ModelSim |
| `syn/` | Synthesis constraints, Docker environment, and Yosys flow |
| `gate/` | Representative gate-level functional simulation |
| `doc/` | Design notes and analysis reports |

## RTL simulation and lint

Run these commands from the repository root in an environment with Verilator.

```sh
# Run the ALIGN_1B and ALIGN_4B regressions.
make -C sim regress

# Lint both configurations.
make -C sim lint
```

Use `make -C sim sim_1b` or `make -C sim sim_4b` to run one configuration.

## Yosys synthesis size

The following results were measured on 2026-09-20 by synthesizing `uart_top`
to generic cells with Yosys 0.68 (`38e001a6f`).

| Configuration | Combinational gates | 1-bit flip-flops | Total cells |
| --- | ---: | ---: | ---: |
| `SYN` + `ALIGN_1B` | 1,771 | 523 | 2,294 |
| `SYN` + `ALIGN_4B` | 1,685 | 523 | 2,208 |

The flow uses `read_slang`, followed by `synth -top uart_top -flatten` and
ABC's default generic-gate mapping. Each combinational cell, including a mux or
inverter, counts as one gate. FFs include enable/reset variants and FIFO storage
mapped to registers.

These figures are not NAND2-equivalent gate counts, FPGA LUT/LE counts, or
physical area. No cell library, clock constraint, or placement and routing is
applied. The final designs contain no latches, unmapped memories, or black
boxes, and `check -assert` passes for both configurations.

### Reproducing the results

Use the Docker environment under `syn/dockerfile`.

```sh
# Build the Docker image if it is not already available.
make -C syn/yosys image

# Synthesize both configurations and refresh results.json.
make -C syn/yosys
```

The recorded run used `fpga-suite_080823:y0.68-v5.050`. The image ID, tool
version, input SHA-256 hashes, and per-cell counts are stored in the
[synthesis results](syn/yosys/results.json). See the
[Yosys synthesis guide](syn/yosys/README.md) for the counting method and output
files.

## Gate-level simulation

Run the representative post-fit functional simulation in an environment with
Quartus Prime and Questa or ModelSim:

```sh
make -C gate
```

See the [gate-level simulation guide](gate/README.md) for tool selection,
generated files, and the timing-simulation limitation.

## License

Project code copyrighted by RedLeafLogic Co., Ltd is distributed under the
[Apache License 2.0](LICENSE).
