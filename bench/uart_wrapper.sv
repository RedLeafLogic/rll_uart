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

`ifdef SYN
/* empty */
`else
timeunit      1ps ;
timeprecision 1ps ;
`endif
module uart_wrapper
import uart_top_package:: *;
 (wb_ext_bus wb_ext_bus, uart_bus uart_bus) ;

   logic [31:0] dat_o ;
   logic        ack_o ;
   logic        intr_o ;
   logic        stx_o ;
   logic        rts_o ;
   logic        dtr_o ;
   
   wire        clk_i   = wb_ext_bus.clk_i ;
   wire        nrst_i  = wb_ext_bus.nrst_i ;
   wire [15:0] adr_i   = wb_ext_bus.adr_i ;
   wire [31:0] dat_i   = wb_ext_bus.dat_i ;
   wire        we_i    = wb_ext_bus.we_i  ;
   wire [3:0]  sel_i   = wb_ext_bus.sel_i ;
   wire        stb_i   = wb_ext_bus.stb_i ;
   wire        cyc_i   = wb_ext_bus.cyc_i ;

   assign wb_ext_bus.dat_o  = dat_o ;
   assign wb_ext_bus.ack_o  = ack_o ;
   assign wb_ext_bus.intr_o = intr_o ;
   assign uart_bus.stx_o = stx_o ;
   assign uart_bus.rts_o = rts_o ;
   assign uart_bus.dtr_o = dtr_o ;

/* verilator lint_off UNOPTFLAT */
   wire        srx_i   = uart_bus.srx_i ;
   wire        cts_i   = uart_bus.cts_i ;
   wire        dsr_i   = uart_bus.dsr_i ;
   wire        ri_i    = uart_bus.ri_i ;
   wire        dcd_i   = uart_bus.dcd_i ;
/* verilator lint_on UNOPTFLAT */   
   uart_top ut(.*) ;
   
endmodule
