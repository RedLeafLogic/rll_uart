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

`ifndef SYN
timeunit 1ps;
timeprecision 1ps;
`endif

// Fixed UART FIFO: sixteen entries of {PE, FE, BI, data[7:0]}.
module uart_fifo
  import fifo_package::*;
  (input wire clk_i,
   input wire nrst_i,
   input wire clear,
   input wire clear_head_error,
   input wire [1:0] almost_empty_level,
   fifo_bus.pop_slave_mp fifo_pop,
   fifo_bus.push_slave_mp fifo_push,
   output wire all_error);

   u_fifo_t u_fifo;
   logic [4:0] count;
   logic [10:0] fifo_mem [0:15];
   logic [15:0] error_valid;
   logic [4:0] trigger_level;
   wire empty = count == 5'd0;
   wire full = count == 5'd16;
   wire do_pop = nrst_i && !clear && fifo_pop.pop && !empty;
   // Full FIFO may replace the entry being read on this edge.
   // Empty FIFO does not bypass a simultaneous write to the reader.
   wire do_push = nrst_i && !clear && fifo_push.push && (!full || do_pop);

   assign fifo_pop.empty = empty;
   assign fifo_pop.full = full;
   assign fifo_push.empty = empty;
   assign fifo_push.full = full;
   assign fifo_pop.almost_full = count >= trigger_level;
   assign fifo_push.almost_full = count >= trigger_level;
   assign fifo_pop.pop_accept = do_pop;
   assign fifo_push.push_accept = do_push;
   assign fifo_pop.pop_dat = empty ? 11'b0 : fifo_mem[u_fifo.read_pointer];
   assign all_error = |error_valid;

   always_comb begin
      case (almost_empty_level)
         2'b00: trigger_level = LEVEL_1;
         2'b01: trigger_level = LEVEL_2;
         2'b10: trigger_level = LEVEL_3;
         2'b11: trigger_level = LEVEL_4;
         default: trigger_level = LEVEL_1;
      endcase
   end

   always_ff @(posedge clk_i or negedge nrst_i) begin
      if (!nrst_i) begin
         u_fifo <= '0;
         count <= '0;
         error_valid <= '0;
      end else if (clear) begin
         u_fifo <= '0;
         count <= '0;
         error_valid <= '0;
      end else begin
         case ({do_push, do_pop})
            2'b10: count <= count + 5'd1;
            2'b01: count <= count - 5'd1;
            default: ;
         endcase
         if (clear_head_error && !empty)
            error_valid[u_fifo.read_pointer] <= 1'b0;
         if (do_pop) begin
            u_fifo.read_pointer <= u_fifo.read_pointer + 4'd1;
            error_valid[u_fifo.read_pointer] <= 1'b0;
         end
         // Write wins if read and write pointers identify the same slot.
         if (do_push) begin
            u_fifo.write_pointer <= u_fifo.write_pointer + 4'd1;
            error_valid[u_fifo.write_pointer] <= |fifo_push.push_dat[10:8];
         end
      end
   end

   // Memory need not be reset: empty masks its output, and every valid slot
   // has been written. Keeping reset off the array allows RAM inference.
   always_ff @(posedge clk_i) begin
      if (do_push)
         fifo_mem[u_fifo.write_pointer] <= fifo_push.push_dat;
   end
endmodule
