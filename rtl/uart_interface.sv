/* *****************************************************************************
   * title:         uart_16550_rll module                                      *
   * description:   RS232 Protocol 16550D uart (mostly supported)              *
   * languages:     systemVerilog                                              *
   *                                                                           *
   * Copyright (C) 2010, 2026 RedLeafLogic Co., Ltd                                  *
   *                                                                           *
   * Licensed under the Apache License, Version 2.0 (the "License");
   * you may not use this file except in compliance with the License.
   * You may obtain a copy of the License at
   *
   *     https://www.apache.org/licenses/LICENSE-2.0
   *
   * Unless required by applicable law or agreed to in writing, software
   * distributed under the License is distributed on an "AS IS" BASIS,
   * WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
   * See the License for the specific language governing permissions and
   * limitations under the License.
   * SPDX-License-Identifier: Apache-2.0
   *****************************************************************************
   *                            RedLeafLogic Co., Ltd                          *
   ***************************************************************************** */
// --- uart16550 interface signale ---
`ifdef SYN
/* empty */
`else
timeunit      1ps ;
timeprecision 1ps ;
`endif
// This file intentionally groups the UART and Wishbone interfaces.
/* verilator lint_off DECLFILENAME */
interface uart_bus();
/* verilator lint_off UNOPTFLAT */
   wire  stx_o ;
   wire  srx_i ;
   wire  rts_o ;
   wire  cts_i ;
   wire  dtr_o ;
   wire  dsr_i ;
   wire  ri_i ;
   wire  dcd_i ;
/* verilator lint_on UNOPTFLAT */   
endinterface : uart_bus

interface wb_bus() ;
   wire  clk_i ;   // clock 
   wire  nrst_i ;  // reset 
   wire [31:0] adr_i ;   // address
   wire [31:0] dat_i ;   // data input
   wire [31:0]  dat_o ;   // data output
   wire         we_i  ;   // write enable
   wire [3:0]   sel_i ;   // select
   wire         stb_i ;   // strobe signal
   wire         ack_o ;   // acknowledge
   wire         cyc_i ;   // cycle assrted
   wire         intr_o ;  // interrupt output
   
   modport master_mp(
                     output  clk_i, nrst_i, adr_i, dat_i, we_i, sel_i, cyc_i, stb_i,
                     input  dat_o, ack_o, intr_o
                     ) ;
   
   modport slave_mp(
                    input  clk_i, nrst_i, adr_i, dat_i, we_i, sel_i, stb_i, cyc_i,
                    output dat_o, ack_o, intr_o) ;
   
endinterface : wb_bus
/* verilator lint_on DECLFILENAME */

