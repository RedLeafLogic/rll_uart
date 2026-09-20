# Generic UART synthesis

Run `make -C syn/yosys` from the repository root. The Makefile uses the image
name from the defaults in `../dockerfile/make_env`:
`fpga-suite_080823:y0.68-v5.050`. Build it with `make -C syn/yosys image`, which
invokes that launcher and its supplied Dockerfile. Both targets accept
`DOCKER=...` and `IMAGE_NAME=...` overrides. From inside the supplied container,
`make -C syn/yosys local` also works (image identity is then unspecified unless
`SYNTH_IMAGE` and `SYNTH_IMAGE_ID` are set).

The measurement uses the existing image; it does not claim that the image was
rebuilt from the current Dockerfile. `results.json` records the actual image ID
and Yosys version, alongside hashes of the current Docker recipe and inputs.

## Flow and counting

`run.py` runs two independent Yosys processes, defining `SYN` and either
`ALIGN_1B` or `ALIGN_4B`. It reads `../../sim/uart_rtl.list` using `read_slang -F`,
so SystemVerilog packages and interfaces are elaborated directly. It then runs:

```text
synth -top uart_top -flatten
check -assert
stat -json
write_json ...
```

`synth` maps FIFO memories into registers and uses ABC's default generic gate
set. No Intel/Altera files are inputs. No Liberty library or timing target is
used. The top-level inputs are unconstrained; unused/debug logic is optimized
away normally.

The count is taken from the final JSON netlist. NOT, AND, NAND, OR, NOR, XOR,
XNOR, ANDNOT, ORNOT and MUX cells each contribute one combinational gate.
Every one-bit DFF/DFFE/SDFF-family cell contributes one FF, including its
reset/enable functionality. The script rejects unknown cell types, remaining
hierarchy, and unmapped memories instead of silently omitting them. This is a
generic cell count, not NAND2-equivalent area or a prediction of FPGA resources.
See the [Yosys ABC command documentation](https://yosyshq.readthedocs.io/projects/yosys/en/v0.68/cmd/abc.html)
for generic mapping details.

## Outputs

- `results.json`: shareable summary, detailed cell counts, tool/image identity,
  and SHA-256 hashes of inputs and synthesis scripts.
- `build/ALIGN_1B/` and `build/ALIGN_4B/`: generated `synth.ys`, full `yosys.log`,
  raw `stat.json`, and mapped `netlist.json`. These working files are ignored
  by Git and regenerated on each run.

The recorded results are 1,771 gates / 523 FFs for `ALIGN_1B` and 1,685 gates /
523 FFs for `ALIGN_4B`. Both frontend runs report zero errors and zero warnings,
and both final `check -assert` runs report zero problems. ABC emits
`The network is combinational` during its default script because only the
combinational logic is passed to ABC; the 523 FFs remain in the Yosys netlist.
This size measurement does not establish timing closure or functional equivalence.

After changing RTL or the tool image, rerun synthesis and update the README
tables to match `results.json`.
