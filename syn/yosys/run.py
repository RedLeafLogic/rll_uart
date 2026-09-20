#!/usr/bin/env python3
# Copyright (C) 2026 RedLeafLogic Co., Ltd
# SPDX-License-Identifier: Apache-2.0
"""Synthesize both bus alignments and count generic gates and 1-bit FFs."""
import hashlib
import json
import os
from pathlib import Path
import subprocess
from collections import Counter

HERE = Path(__file__).resolve().parent
ROOT = HERE.parent.parent
COMB = {f"$_{name}_" for name in (
    "NOT", "AND", "NAND", "OR", "NOR", "XOR", "XNOR", "ANDNOT", "ORNOT", "MUX"
)}


def main():
    os.chdir(HERE)
    filelist = ROOT / "sim/uart_rtl.list"
    sources = [(filelist.parent / line.strip()).resolve()
               for line in filelist.read_text().splitlines() if line.strip()]
    version = subprocess.check_output(["yosys", "-V"], text=True).strip()
    results = []
    for align in ("ALIGN_1B", "ALIGN_4B"):
        out = Path("build") / align
        out.mkdir(parents=True, exist_ok=True)
        script = out / "synth.ys"
        script.write_text(
            f"read_slang --top uart_top -DSYN -D{align} -F ../../sim/uart_rtl.list\n"
            "synth -top uart_top -flatten\n"
            "check -assert\n"
            f"tee -o {out}/stat.json stat -json\n"
            f"write_json {out}/netlist.json\n"
        )
        with (out / "yosys.log").open("w") as log:
            process = subprocess.run(["yosys", "-T", "-s", str(script)],
                                     stdout=log, stderr=subprocess.STDOUT)
        if process.returncode:
            raise SystemExit(f"{align}: synthesis failed; see {out}/yosys.log")
        design = json.loads((out / "netlist.json").read_text())
        if set(design["modules"]) != {"uart_top"}:
            raise SystemExit(f"{align}: unexpected remaining hierarchy")
        module = design["modules"]["uart_top"]
        if module.get("memories"):
            raise SystemExit(f"{align}: unmapped memories remain")
        counts = Counter(cell["type"] for cell in module["cells"].values())
        ff_types = {t for t in counts if t.startswith(("$_DFF", "$_SDFF"))}
        unknown = set(counts) - COMB - ff_types
        if unknown:
            raise SystemExit(f"{align}: unclassified cells: {sorted(unknown)}")
        for cell in module["cells"].values():
            if cell["type"] in ff_types and len(cell["connections"]["Q"]) != 1:
                raise SystemExit(f"{align}: non-bit FF encountered")
        result = {
            "configuration": align,
            "combinational_gates": sum(counts[t] for t in COMB),
            "flip_flops": sum(counts[t] for t in ff_types),
            "total_cells": sum(counts.values()),
            "cells_by_type": dict(sorted(counts.items())),
        }
        results.append(result)
        print(f"{align}: {result['combinational_gates']} gates, "
              f"{result['flip_flops']} FFs, {result['total_cells']} total cells")
    inputs = sources + [filelist, HERE / "run.py", HERE / "Makefile",
                        ROOT / "syn/dockerfile/Dockerfile", ROOT / "syn/dockerfile/make_env"]
    report = {
        "yosys_version": version,
        "docker_image": os.environ.get("SYNTH_IMAGE", "unspecified (local run)"),
        "docker_image_id": os.environ.get("SYNTH_IMAGE_ID", "unspecified"),
        "top": "uart_top",
        "flow": "read_slang -DSYN; synth -top uart_top -flatten; check -assert",
        "metric": "Generic combinational cells (including mux/inverter); one-bit FF cells. Not NAND2 equivalents.",
        "source_sha256": {str(p.relative_to(ROOT)): hashlib.sha256(p.read_bytes()).hexdigest()
                          for p in inputs},
        "results": results,
    }
    (HERE / "results.json").write_text(json.dumps(report, indent=2) + "\n")


if __name__ == "__main__":
    main()
