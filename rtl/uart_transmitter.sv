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

module uart_transmitter
  import uart_package::*;
  (input wire clk_i,
   input wire nrst_i,
   input wire trans_clk_en,
   input wire trans_half_en,
   input wire [5:0] line_format,
   input wire break_control,
   output wire txd_out,
   fifo_bus.pop_master_mp fifo_pop,
   output u_codec_t trans_codec,
   output wire trans_buf_empty);

   codec_state_t state;
   logic [7:0] data_r;
   logic line;
   uart_format_t frame_format;
   codec_state_t next_state;
   wire [2:0] last_bit = 3'd4 + {1'b0, frame_format.char_length};
   wire parity_bit = uart_parity(data_r, frame_format.char_length,
                                 frame_format.even_parity, frame_format.stick_parity);
   wire advance = trans_clk_en ||
                  (state == STOP_EXTRA &&
                   frame_format.char_length == CHAR_5_BIT && trans_half_en);

   uart_codec_state trans_state(
      .state(state), .char_length(frame_format.char_length),
      .parity_enable(frame_format.parity_enable),
      .stop_bit_count(frame_format.stop_bit_count), .next_state(next_state));

   assign fifo_pop.pop = state == IDLE && !fifo_pop.empty;
   assign trans_codec = {data_r, fifo_pop.pop_accept, line, 3'b0, state};
   assign trans_buf_empty = state == IDLE;
   assign txd_out = break_control ? 1'b0 : line;

   always_ff @(posedge clk_i or negedge nrst_i) begin
      if (!nrst_i) begin
         frame_format <= uart_format_t'(6'h03);
         state <= IDLE;
         data_r <= '0;
         line <= 1'b1;
      end else if (state == IDLE) begin
         if (fifo_pop.pop_accept) begin
            frame_format <= uart_format_t'(line_format);
            data_r <= fifo_pop.pop_dat[7:0];
            line <= 1'b0;
            state <= START;
         end
      end else if (advance) begin
         state <= next_state;
         case (next_state)
            SEL_0: line <= data_r[0];
            SEL_1: line <= data_r[1];
            SEL_2: line <= data_r[2];
            SEL_3: line <= data_r[3];
            SEL_4: line <= data_r[4];
            SEL_5: line <= data_r[5];
            SEL_6: line <= data_r[6];
            DATA_END: line <= data_r[last_bit];
            PARITY: line <= parity_bit;
            default: line <= 1'b1;
         endcase
      end
   end
endmodule
