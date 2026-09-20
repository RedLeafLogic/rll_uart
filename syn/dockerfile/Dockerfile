# ==========================================
# FPGA OSS CAD Suite
#   Yosys      : v0.68 (sv-elab / slang)
#   Verilator  : v5.050
#
# NOTE:
# Yosys >= 0.67 requires:
#   - CMake >= 3.28
#   - C++20
#   - GCC >= 13 or Clang >= 16
# Therefore Debian 13 (trixie) is used instead of bookworm.
# ==========================================

# ==========================================
# Stage 1: Builder
# ==========================================
FROM debian:trixie-slim AS builder

ARG YOSYS_TAG=v0.68
ARG VERILATOR_TAG=v5.050
ARG SBY_TAG=v0.68
ARG YICES2_TAG=yices-2.7.0
ARG CC65_COMMIT=e11fb5c39371046ebe25485f984f644c5a0d65d3

ENV DEBIAN_FRONTEND=noninteractive

# 1. Common build dependencies
RUN apt-get update && apt-get install -y --no-install-recommends \
    ca-certificates \
    build-essential \
    clang \
    bison \
    flex \
    libfl-dev \
    perl \
    libreadline-dev \
    gawk \
    tcl-dev \
    libffi-dev \
    git \
    graphviz \
    xdot \
    pkg-config \
    python3 \
    python3-pip \
    libboost-system-dev \
    libboost-python-dev \
    libboost-filesystem-dev \
    zlib1g-dev \
    curl \
    wget \
    cmake \
    ninja-build \
    libftdi-dev \
    gperf \
    autoconf \
    help2man \
    z3 \
    libgmp-dev \
    && rm -rf /var/lib/apt/lists/*

WORKDIR /work/src

# ---------------------------------------------------------
# 2. Simulation: Verilator v5.050
# ---------------------------------------------------------
RUN git clone --depth 1 --branch "${VERILATOR_TAG}" \
        https://github.com/verilator/verilator.git && \
    cd verilator && \
    autoconf && \
    ./configure && \
    make -j"$(nproc)" && \
    make install && \
    verilator --version

# ---------------------------------------------------------
# 3. RTL synthesis / SystemVerilog: Yosys v0.68
#    Yosys 0.67+ uses CMake and integrates sv-elab/slang.
# ---------------------------------------------------------
RUN git clone --depth 1 --branch "${YOSYS_TAG}" \
        https://github.com/YosysHQ/yosys.git && \
    cd yosys && \
    git submodule update --init --recursive && \
    cmake -B build . \
        -DCMAKE_BUILD_TYPE=Release && \
    cmake --build build \
        --config Release \
        --parallel "$(nproc)" && \
    cmake --install build --strip && \
    yosys -V

# SystemVerilog frontend smoke test:
# package + typedef enum + logic + always_ff are actually parsed/elaborated.
#
# NOTE: must use read_slang, not read -sv. Yosys's native Verilog-2005
#   frontend (invoked by "-sv") does not implement `package` / `import`,
#   and fails with "syntax error, unexpected TOK_IMPORT". This image's
#   actual SV support (packages, bind, packed structs/enums used
#   throughout rtl/timer2ch_pkg.sv) comes entirely from read_slang, so
#   the smoke test has to exercise that frontend to mean anything.
RUN printf '%s\n' \
    'package smoke_pkg;' \
    '  typedef enum logic [1:0] { IDLE, RUN } state_t;' \
    'endpackage' \
    'module smoke_top(input logic clk, input logic rst, output logic q);' \
    '  import smoke_pkg::*;' \
    '  state_t state;' \
    '  always_ff @(posedge clk) begin' \
    '    if (rst) begin state <= IDLE; q <= 1'"'"'b0; end' \
    '    else begin state <= RUN; q <= (state == RUN); end' \
    '  end' \
    'endmodule' \
    > /tmp/yosys_sv_smoke.sv && \
    yosys -Q -p 'read_slang /tmp/yosys_sv_smoke.sv; hierarchy -top smoke_top; proc; check' && \
    rm -f /tmp/yosys_sv_smoke.sv

# ---------------------------------------------------------
# 4. Formal Tools: SymbiYosys (SBY)
# ---------------------------------------------------------
RUN git clone --depth 1 --branch "${SBY_TAG}" \
        https://github.com/YosysHQ/sby.git && \
    cd sby && \
    make install && \
    command -v sby

# ---------------------------------------------------------
# 5. Formal Tools: Yices2 (Solver)
# ---------------------------------------------------------
RUN git clone --depth 1 --branch "${YICES2_TAG}" \
        https://github.com/SRI-CSL/yices2.git && \
    cd yices2 && \
    autoconf && \
    ./configure && \
    make -j"$(nproc)" && \
    make install && \
    yices-smt2 --version

# ---------------------------------------------------------
# 6. 6502 Assembler: cc65 (ca65 / ld65 / cl65 / sim65 ...)
# ---------------------------------------------------------
# No stable tag newer than V2.19 (2023) exists, so master is used
# instead - but pinned to a fixed commit (CC65_COMMIT) rather than
# floating, so the build stays reproducible.
# Note: git tags/branches are content-addressed by their commit SHA,
# so pinning IS the integrity check here - there is no separate
# checksum file to verify against, unlike the Node.js tarball below.
RUN mkdir cc65 && cd cc65 && \
    git init -q && \
    git fetch --depth 1 https://github.com/cc65/cc65.git "${CC65_COMMIT}" && \
    git checkout -q FETCH_HEAD && \
    make -j"$(nproc)" && \
    make install PREFIX=/usr/local && \
    ca65 --version && \
    ld65 --version

# ==========================================
# Stage 2: Final Image
# ==========================================
FROM debian:trixie-slim

ARG YOSYS_TAG=v0.68
ARG VERILATOR_TAG=v5.050
ARG SBY_TAG=v0.68
ARG YICES2_TAG=yices-2.7.0
ARG CC65_COMMIT=e11fb5c39371046ebe25485f984f644c5a0d65d3

LABEL maintainer="Hardware Verification Env"
LABEL description="FPGA Dev: Verilator ${VERILATOR_TAG}, Yosys ${YOSYS_TAG} (sv-elab/slang), SBY ${SBY_TAG}, cocotb, Z3, Yices2 ${YICES2_TAG}, cc65(6502)"
LABEL fpga.yosys.version="${YOSYS_TAG}"
LABEL fpga.verilator.version="${VERILATOR_TAG}"
LABEL fpga.sby.version="${SBY_TAG}"
LABEL fpga.yices2.version="${YICES2_TAG}"
LABEL fpga.cc65.commit="${CC65_COMMIT}"

ENV DEBIAN_FRONTEND=noninteractive

# Runtime packages + Python virtualenv support
#
RUN apt-get update && apt-get install -y --no-install-recommends \
    ca-certificates \
    python3 \
    python3-pip \
    python3-venv \
    git \
    build-essential \
    make \
    libreadline8 \
    tcl \
    libffi8 \
    zlib1g \
    graphviz \
    xdot \
    libboost-system-dev \
    libboost-python-dev \
    libboost-filesystem-dev \
    z3 \
    libgmp-dev \
    less \
    vim \
    curl \
    && apt-get autoremove -y && \
    apt-get clean && \
    rm -rf /var/lib/apt/lists/*

# Copy tools built in the builder stage
COPY --from=builder /usr/local /usr/local

# Refresh dynamic linker cache for anything installed under /usr/local/lib.
RUN ldconfig

# ---------------------------------------------------------
# Python virtualenv + cocotb
# ---------------------------------------------------------
RUN python3 -m venv /opt/venv
ENV PATH="/opt/venv/bin:$PATH"

# NOTE: click is required by SymbiYosys (sby), not just by cocotb.
#   /usr/local/bin/sby has the shebang `#!/usr/bin/env python3`. Because
#   ENV PATH above puts /opt/venv/bin first, `env python3` resolves to
#   THIS venv's interpreter for every RUN/CMD after this point - not the
#   system python - so sby's dependencies must live here, in the venv,
#   not in system site-packages (apt's python3-click would be invisible
#   to it). Earlier images happened to have click pulled in transitively
#   by cocotb; cocotb 2.0.1 no longer depends on it, so it must be listed
#   explicitly or sby fails at startup with:
#     ModuleNotFoundError: No module named 'click'
RUN pip install --no-cache-dir --upgrade pip==26.2.1 && \
    pip install --no-cache-dir \
        cocotb==2.0.1 \
        cocotb-test==0.2.6 \
        cocotb-coverage==2.0 \
        pytest==9.1.1 \
        click==8.5.0

# ---------------------------------------------------------
# RAM disk paths
# /build itself is supplied by make_env using --tmpfs.
# ---------------------------------------------------------
RUN mkdir -p /build && chmod 1777 /build

ENV TMPDIR=/build
ENV SIM_BUILD=/build/sim_build
ENV HOME=/build/home
ENV XDG_CACHE_HOME=/build/.cache
ENV XDG_CONFIG_HOME=/build/.config

# ---------------------------------------------------------
# Node.js (pinned + checksum-verified, for Claude Code below)
#
# NOTE: previously installed via `curl nodesource-script | bash`, which
#   pulls an unpinned, unverified script/package. Instead, fetch an
#   exact release tarball from nodejs.org and verify it against the
#   project's own published SHASUMS256.txt before extracting.
# ---------------------------------------------------------
ARG NODE_VERSION=22.23.2
RUN set -eu; \
    case "$(dpkg --print-architecture)" in \
        amd64) node_arch=x64 ;; \
        arm64) node_arch=arm64 ;; \
        *) echo "unsupported architecture: $(dpkg --print-architecture)" >&2; exit 1 ;; \
    esac; \
    node_pkg="node-v${NODE_VERSION}-linux-${node_arch}.tar.gz"; \
    cd /tmp && \
    curl -fsSLO "https://nodejs.org/dist/v${NODE_VERSION}/${node_pkg}" && \
    curl -fsSLO "https://nodejs.org/dist/v${NODE_VERSION}/SHASUMS256.txt" && \
    grep " ${node_pkg}\$" SHASUMS256.txt | sha256sum -c - && \
    tar -xzf "${node_pkg}" -C /usr/local --strip-components=1 && \
    rm -f "${node_pkg}" SHASUMS256.txt && \
    node --version

# ---------------------------------------------------------
# Claude Code
# ---------------------------------------------------------
RUN npm install -g @anthropic-ai/claude-code

# ---------------------------------------------------------
# cc65 library/include/linker-config search root
# ---------------------------------------------------------
ENV CC65_HOME=/usr/local/share/cc65

# ---------------------------------------------------------
# Final version / installation sanity check
# ---------------------------------------------------------
# NOTE: sby is invoked, not just located. `command -v sby` only proves the
#   file exists and would still pass with a broken Python dependency; running
#   it actually exercises the imports.
RUN yosys -V && \
    verilator --version && \
    sby --help > /dev/null && \
    z3 --version && \
    yices-smt2 --version && \
    ca65 --version && \
    ld65 --version

WORKDIR /work
CMD ["bash"]
