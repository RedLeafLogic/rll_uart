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
// import uart_top_package:: * ;
module uart_top
  (
   input   wire         clk_i,   // clock 
   input   wire         nrst_i,  // reset 
   input   wire [15:0]  adr_i,   // address
   input   wire [31:0]  dat_i,   // data input
   output  wire [31:0]  dat_o,   // clk_rst_manager
   input   wire         we_i,    // write enable
   input   wire [3:0]   sel_i,   // select
   input   wire         stb_i,   // 
   output  wire         ack_o,   // acknowledge accept
   input   wire         cyc_i,   // cycle assrted
   output  wire         intr_o,  // 
   
   output wire          stx_o,
   output wire          rts_o,
   output wire          dtr_o,
   input  wire          srx_i,
   input  wire          cts_i,
   input  wire          dsr_i,
   input  wire          ri_i,
   input  wire          dcd_i
   ) ;
   
   uart_bus uart_bus() ;
   wb_bus   wb_bus() ;

   assign wb_bus.clk_i   = clk_i ;
   assign wb_bus.nrst_i  = nrst_i ;
   assign wb_bus.adr_i   = {16'h0, adr_i} ;
   assign wb_bus.dat_i   = dat_i ;
   assign dat_o          = wb_bus.dat_o ;
   assign wb_bus.we_i    = we_i  ;
   assign wb_bus.sel_i   = sel_i ;
   assign wb_bus.stb_i   = stb_i ;
   assign ack_o          = wb_bus.ack_o ;
   assign wb_bus.cyc_i   = cyc_i ;
   assign intr_o         = wb_bus.intr_o ;
   assign stx_o          = uart_bus.stx_o ;
   assign rts_o          = uart_bus.rts_o ;
   assign dtr_o          = uart_bus.dtr_o ;

   assign uart_bus.srx_i = srx_i ;
   assign uart_bus.cts_i = cts_i ;
   assign uart_bus.dsr_i = dsr_i ;
   assign uart_bus.ri_i  = ri_i ;
   assign uart_bus.dcd_i = dcd_i ;
   
   uart_16550_rll um(.wb_bus(wb_bus.slave_mp)
                     ,.uart_bus(uart_bus)) ;
   
endmodule
