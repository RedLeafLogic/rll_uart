#/* *****************************************************************************
#   * title:         uart_16550_rll module                                      *
#   * description:   RS232 Protocol 16550D uart (mostly supported)              *
#   * languages:     systemVerilog                                              *
#   *                                                                           *
#   * Copyright (C) 2010, 2026 RedLeafLogic Co., Ltd                                  *
#   *                                                                           *
#   * This library is free software; you can redistribute it and/or             *
#   * modify it under the terms of the GNU Lesser General Public                *
#   * License as published by the Free Software Foundation; either              *
#   * version 2.1 of the License, or (at your option) any later version.        *
#   *                                                                           *
#   * This library is distributed in the hope that it will be useful,           *
#   * but WITHOUT ANY WARRANTY; without even the implied warranty of            *
#   * MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the GNU         *
#   * Lesser General Public License for more details.                           *
#   *                                                                           *
#   * You should have received a copy of the GNU Lesser General Public          *
#   * License along with this library; if not, write to the Free Software       *
#   * Foundation, Inc., 59 Temple Place, Suite 330, Boston, MA  02111-1307  USA *
#   *                                                                           *
#   *         ***  GNU LESSER GENERAL PUBLIC LICENSE  ***                       *
#   *           from http://www.gnu.org/licenses/lgpl.txt                       *
#   *****************************************************************************
#   *                            RedLeafLogic Co., Ltd                          *
#   ***************************************************************************** */

.SUFFIXES :
.SUFFIXES : .v .sv .fst

align = ALIGN_4B

all: uart_test_${align}.fst

uart_test_${align}.fst: uart_test.sv
##	verilator -Wall -o $* -sv -stats --timing --binary --trace-fst -trace-depth 5 --trace-structs -f uart_rtl.list -f uart_be.list +define+${align}+DUMP_VCD+
	mkdir -p DUMP
	CCACHE_DIR=/tmp/uart_ccache verilator -o uart_test -sv -stats --dump-dfg --hierarchical --top-module top --timing --binary --trace-fst --trace-depth 10 --trace-structs -f uart_rtl.list -f uart_be.list +define+${align}+DUMP_VCD+
	./obj_dir/uart_test
	mv dump.fst $@
	mv uar_16550_rll.dump ./DUMP/uart_test_a_${align}.dump

.PHONY: sim_4b sim_1b regress
sim_4b:
	${MAKE} align=ALIGN_4B uart_test_ALIGN_4B.fst

sim_1b:
	${MAKE} align=ALIGN_1B uart_test_ALIGN_1B.fst

regress: sim_4b sim_1b

clean:
	- \rm -rf  *.bak *~

clean_all:
	- \rm -rf ./obj_dir *.fst  *.diff_log *.dump ./DUMP/*.dump ./DUMP_GATE/*.dump ./LOG/*.log *.log
	${MAKE} clean

diff:
	diff -q  ./DUMP ./EXP > ${TEST_CONDITION}_diff.log



# Static RTL checks only: no simulation executable is built or run.
.PHONY: lint
lint:
	verilator --lint-only --timing -Wall --top-module uart_top -f uart_rtl.list +define+ALIGN_4B
	verilator --lint-only --timing -Wall --top-module uart_top -f uart_rtl.list +define+ALIGN_1B
	verilator --lint-only --no-timing -Wall --top-module uart_top -f uart_rtl.list +define+SYN+ALIGN_4B
	verilator --lint-only --no-timing -Wall --top-module uart_top -f uart_rtl.list +define+SYN+ALIGN_1B
