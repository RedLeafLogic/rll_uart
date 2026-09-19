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
/* verilator lint_off DECLFILENAME */
interface wb_ext_bus
/* verilator lint_on DECLFILENAME */
import uart_top_package:: *;
();
   wire                     clk_i ;   // clock 
   wire                     nrst_i ;  // reset 
   wire [15:0]              adr_i ;   // address
   wire [31:0]              dat_i ;   // data input
   wire [31:0]              dat_o ;   // clk_rst_manager
   wire                     we_i  ;   // write enable
   wire [3:0]               sel_i ;   // select
   wire                     stb_i ;   // 
   wire                     ack_o ;   // acknowledge accept
   wire                     cyc_i ;   // cycle assrted
   wire                     intr_o ;  //
   logic                    clk_b; 
   
   modport master_mp(
                     output  clk_i, nrst_i, adr_i, dat_i, we_i, sel_i, cyc_i, stb_i,
                     input  dat_o, ack_o, intr_o
                     ) ;
   
   modport slave_mp(
                    input  clk_i, nrst_i, adr_i, dat_i, we_i, sel_i, stb_i, cyc_i,
                    output dat_o, ack_o, intr_o) ;
   
   
   logic [31:0]            bw_data ;
   logic [4:0]             b_addr ;
   logic                   cs3, we ;
   logic [3:0]             be ;
   
   assign adr_i = {11'h0, b_addr};
   assign dat_i = we == 1'b1 ? bw_data : 'hx ;
   assign stb_i = cs3 ;
   assign cyc_i = cs3 ;
   assign we_i  = we ;
   assign sel_i = be ;
   assign clk_b = clk_i ;
   
   initial begin
      bw_data = 0 ;
      b_addr  = 0;
      cs3  = 1'b0 ;
      we   = 1'b0 ;
      be   = 4'b0000 ;
   end     
   
   task write(
              input logic [31:0] wdat,
              input logic [4:0] adr
              ) ;
      @(posedge clk_b) ;
      #(STEP*0.1) ;
`ifdef ALIGN_4B
      b_addr = {adr[2:0], 2'b00};
`else
      b_addr = adr;
`endif
      cs3  = 1'b1 ;
      @(posedge clk_b) ;
      #(STEP*0.1) ;
`ifdef ALIGN_4B
      bw_data = wdat;
`else
      bw_data = wdat << (8*adr[1:0]);
`endif
      we  = 1'b1 ;
`ifdef ALIGN_4B
      be  = 4'b1111 ;
`else
      be[0]  = adr[1:0] == 2'b00 ;
      be[1]  = adr[1:0] == 2'b01 ;
      be[2]  = adr[1:0] == 2'b10 ;
      be[3]  = adr[1:0] == 2'b11 ;
`endif
      @(posedge clk_b) ;
      #(STEP*0.1) ;
      cs3  = 1'b0 ;
      we   = 1'b0 ;
      be   = 4'b0000 ;
      b_addr   = 5'hx ;
      bw_data  = 32'hx ;
   endtask
   
   task read(
             output logic [31:0] rdat,
             input logic [4:0] adr
             ) ;
      @(posedge clk_b) ;
      #(STEP*0.1) ;
`ifdef ALIGN_4B
      b_addr = {adr[2:0], 2'b00};
`else
      b_addr = adr;
`endif
      cs3  = 1'b1 ;
      we   = 1'b0 ;
      be   = 4'b0000 ;
      @(posedge clk_b) ;
      #(STEP*0.1) ;
      @(posedge clk_b) ;
      #(STEP*0.1) ;
      cs3  = 1'b1 ;
      we   = 1'b0 ;
`ifdef ALIGN_4B
      be  = 4'b1111 ;
`else
      be[0]  = adr[1:0] == 2'b00 ;
      be[1]  = adr[1:0] == 2'b01 ;
      be[2]  = adr[1:0] == 2'b10 ;
      be[3]  = adr[1:0] == 2'b11 ;
`endif
      @(posedge clk_b) ;
`ifdef ALIGN_4B
      rdat = dat_o;
`else
      rdat = dat_o >> (8*adr[1:0]);
`endif
      #(STEP*0.1) ;
      cs3  = 1'b0 ;
      we   = 1'b0 ;
      be   = 4'b0000 ;
      b_addr   = 5'hx ;
      bw_data  = 32'hx ;
   endtask

   task nop() ;
      @(posedge clk_b) ;
      #(STEP*0.1) ;
      b_addr   = 5'hx ;
      bw_data  = 32'hx ;
      cs3 = 1'b0 ;
      we  = 1'b0 ;
      be  = 4'b0000 ;
   endtask

endinterface : wb_ext_bus

