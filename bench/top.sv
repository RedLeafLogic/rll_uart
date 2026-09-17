/* *****************************************************************************
   * title:         uart_16550_rll module                                      *
   * description:   RS232 Protocol 16550D uart (mostly supported)              *
   * languages:     systemVerilog                                              *
   *                                                                           *
   * Copyright (C) 2010, 2026 RedLeafLogic Co., Ltd                                  *
   *                                                                           *
   * This library is free software; you can redistribute it and/or             *
   * modify it under the terms of the GNU Lesser General Public                *
   * License as published by the Free Software Foundation; either              *
   * version 2.1 of the License, or (at your option) any later version.        *
   *                                                                           *
   * This library is distributed in the hope that it will be useful,           *
   * but WITHOUT ANY WARRANTY; without even the implied warranty of            *
   * MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the GNU         *
   * Lesser General Public License for more details.                           *
   *                                                                           *
   * You should have received a copy of the GNU Lesser General Public          *
   * License along with this library; if not, write to the Free Software       *
   * Foundation, Inc., 59 Temple Place, Suite 330, Boston, MA  02111-1307  USA *
   *                                                                           *
   *         ***  GNU LESSER GENERAL PUBLIC LICENSE  ***                       *
   *           from http://www.gnu.org/licenses/lgpl.txt                       *
   *****************************************************************************
   *                            RedLeafLogic Co., Ltd                          *
   ***************************************************************************** */

`ifdef SYN
/* empty */
`else
timeunit      1ps ;
timeprecision 1ps ;
`endif
module top
import uart_top_package:: * ;
import uart_package:: * ;
    () ;

   logic        clk_sys ;
   logic        rst_p ;
   logic        intr_o, bench_intr_o ;
   logic [31:0] rdat, rdat1, rdat2, dat, wdat ;
   integer      i, j, k ;
   logic        ri, dcd ;
   
   u_reg_t     UART_R ;
   uart_bus    uart_bus_DUT() ;
   uart_bus    uart_bus_BENCH() ;
   wb_ext_bus  wb_DUT() ;
   wb_ext_bus  wb_BENCH() ;
   
   assign wb_DUT.clk_i    = clk_sys ;
   assign wb_DUT.nrst_i   = ~rst_p ;
   assign wb_BENCH.clk_i  = clk_sys ;
   assign wb_BENCH.nrst_i = ~rst_p ;

   // --------------
   // -  initial   -
   // --------------
   initial clock_sys ;
   initial test_pat() ;
   initial fst_out();
   // initial vcd_out();

   // ------------
   // -   task   -
   // ------------
   // -- VCD file output --
   task fst_out() ;
      $display("************ fst_out ********************") ;
      $dumpfile("dump.fst");
      $dumpvars();
   endtask   
   task vcd_out() ;
      $display("************ vcd_out ********************") ;
      $dumpfile("dump.vcd");
//      $dumpvars(6,timer_be.tw0);
      $dumpvars();
   endtask

   task test_pat();
      logic [31:0] file_a;
      time         frame_start, frame_end, frame_time;

      file_a = $fopen("uar_16550_rll.dump") ;
      ri = 1'b0 ;
      dcd = 1'b0 ;
      
      rst_p = 1'b1 ;
      #(STEP*20) ;
      rst_p = 1'b0 ;

 `include "uart_test.sv"

      $display(" ----------- happy end SIM !!!  --------------") ;
      
      $fclose(file_a) ;
      
 //     $stop ;
      $finish ;
   endtask
   task clock_sys ;
      clk_sys = 0 ;
      #(STEP) ;
      forever #(STEP/2) clk_sys = ~clk_sys ;
   endtask
   
   assign intr_o = wb_DUT.intr_o ;
   assign bench_intr_o = wb_BENCH.intr_o ;

   assign uart_bus_DUT.srx_i   = uart_bus_BENCH.stx_o ;
   assign uart_bus_DUT.cts_i   = uart_bus_BENCH.rts_o ;
   assign uart_bus_DUT.dsr_i   = uart_bus_BENCH.dtr_o ;
   assign uart_bus_BENCH.srx_i = uart_bus_DUT.stx_o ;
   assign uart_bus_BENCH.cts_i = uart_bus_DUT.rts_o ;
   assign uart_bus_BENCH.dsr_i = uart_bus_DUT.dtr_o ;

   assign uart_bus_DUT.ri_i    = ri ;
   assign uart_bus_DUT.dcd_i   = dcd ;
   assign uart_bus_BENCH.ri_i  = 1'b0 ;
   assign uart_bus_BENCH.dcd_i = 1'b0 ;

   // ----------
   // -   DUT  -
   // ----------
   uart_wrapper DUT(.wb_ext_bus(wb_DUT),
                    .uart_bus(uart_bus_DUT)) ;

   uart_wrapper BENCH(.uart_bus(uart_bus_BENCH),
                      .wb_ext_bus(wb_BENCH)) ;
endmodule
