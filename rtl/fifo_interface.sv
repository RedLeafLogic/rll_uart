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
interface fifo_bus (input clk_i) ;
/* verilator lint_on DECLFILENAME */
   import fifo_package::* ;
   //   wire [DATA_WIDTH-1:0] push_dat ;
   //   wire [DATA_WIDTH-1:0] pop_dat ;
   wire [10:0]           push_dat ;
   wire [10:0]           pop_dat ;
   wire                  push ;
   wire                  pop ;
   wire                  empty ;
   wire                  full ;
   wire                  almost_full ;
   wire                  push_accept ;
   wire                  pop_accept ;
   // Clock is for optional BFM tasks; full remains available to monitors.
   wire unused_monitor = clk_i ^ full;
   
   modport push_master_mp (
                           output push_dat, push,
                           input  full, almost_full, push_accept
                           ) ;
   
   modport push_slave_mp (
                          input  push_dat, push,
                          output full, almost_full, empty, push_accept
                          ) ;
   
   modport pop_master_mp (
                          output pop,
                          input  pop_dat, empty, almost_full, full, pop_accept
                          ) ;
   
   modport pop_slave_mp (
                         input  pop,
                         output pop_dat, empty, almost_full, full, pop_accept
                         ) ;
   
`ifdef SIM
   import fifo_be_package:: * ;
   
   logic [10:0]                 pop_d ;
   logic [10:0]                 push_d ;
   logic                        pop_en;
   logic                        push_en ;
   logic [10:0]                 data ;
   
   assign push_dat      = push_d ;
   assign push          = push_en ;
   assign pop_d         = pop_dat ;
   assign pop           = pop_en ;
   
   initial begin
      push_d = 0 ;
      pop_en = 0 ;
      push_en = 0 ;
   end
   
   task burst_read(output logic [10:0] data) ;
      @(posedge clk_i) ;
      #(STEP*0.1) ;
      data = pop_d ;
      pop_en = 1'b1 ;
   endtask // read
   
   task burst_write(input logic [10:0] data) ;
      @(posedge clk_i) ;
      #(STEP*0.1) ;
      push_d  = data ;
      push_en = 1'b1 ;
   endtask // write

   task read(output logic [10:0] data) ;
      @(posedge clk_i) ;
      #(STEP*0.1) ;
      data = pop_d ;
      pop_en = 1'b1 ;
      @(posedge clk_i) ;
      #(STEP*0.1) ;
      pop_en = 1'b0 ;
   endtask // read
   
   task write(input logic [10:0] data) ;
      @(posedge clk_i) ;
      #(STEP*0.1) ;
      push_d  = data ;
      push_en = 1'b1 ;
      @(posedge clk_i) ;
      #(STEP*0.1) ;
      push_d  = 'hxx ;
      push_en = 1'b0 ;
   endtask // write

   task nop() ;
      @(posedge clk_i) ;
      #(STEP*0.1) ;
      push_d  = 11'hxxx ;
      pop_en  = 1'b0 ;
      push_en = 1'b0 ;
   endtask // write

`endif //  `ifdef SIM
   
endinterface

