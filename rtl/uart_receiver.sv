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

module uart_receiver
  import uart_package::*;
  (input wire clk_i,
   input wire nrst_i,
   input wire rxd_clean,
   input wire rec_sample_pulse,
   input wire rec_bit_end,
   input wire [5:0] line_format,
   fifo_bus.push_master_mp fifo_push,
   output wire rec_active);

   u_codec_t rec_codec;
   codec_state_t state;
   logic [7:0] data_r;
   logic parity_err, framing_err, break_err;
   uart_format_t frame_format;
   codec_state_t next_state;
   logic rxd_previous;
   logic frame_all_low;
   logic push_dly;
   logic [1:0] break_halves_left;
   wire start_edge = rxd_previous && !rxd_clean;
   wire [2:0] last_bit = 3'd4 + {1'b0, frame_format.char_length};
   wire parity_bit = uart_parity(data_r, frame_format.char_length,
                                 frame_format.even_parity, frame_format.stick_parity);

   uart_codec_state rec_state(
      .state(state), .char_length(frame_format.char_length),
      .parity_enable(frame_format.parity_enable),
      .stop_bit_count(1'b0), .next_state(next_state));

   assign rec_codec = {data_r, (state == IDLE && start_edge), rxd_clean,
                       framing_err, parity_err, break_err, state};
   // Waveform-only snapshot. RX checks the first stop bit for FE;
   // break qualification additionally waits for the full configured frame.
   wire unused_snapshot = ^rec_codec;
   assign rec_active = state != IDLE && state != WAIT_HIGH;
   assign fifo_push.push = push_dly;
   assign fifo_push.push_dat = {parity_err, framing_err,
                                break_err, data_r};

   always_ff @(posedge clk_i or negedge nrst_i) begin
      if (!nrst_i) begin
         rxd_previous <= 1'b1;
         frame_format <= uart_format_t'(6'h03);
         frame_all_low <= 1'b0;
         state <= IDLE;
         data_r <= '0;
         parity_err <= 1'b0;
         framing_err <= 1'b0;
         break_err <= 1'b0;
         push_dly <= 1'b0;
         break_halves_left <= '0;
      end else begin
         rxd_previous <= rxd_clean;
         push_dly <= 1'b0;
         if (rec_active && rxd_clean)
            frame_all_low <= 1'b0;
         if (state == IDLE) begin
            if (start_edge) begin
               frame_format <= uart_format_t'(line_format);
               state <= START;
               data_r <= '0;
               parity_err <= 1'b0;
               framing_err <= 1'b0;
               break_err <= 1'b0;
               frame_all_low <= 1'b1;
            end
         end else if (state == WAIT_HIGH) begin
            // A continuous break produces only one received character.
            if (rxd_clean)
               state <= IDLE;
         end else if (state == BREAK_CHECK) begin
            // Stop was low after an all-low frame. Require the remaining
            // stop duration before declaring a break, independently of PE.
            if (rec_sample_pulse || rec_bit_end) begin
               if (break_halves_left == 2'd1) begin
                  break_err <= frame_all_low && !rxd_clean;
                  push_dly <= 1'b1;
                  state <= rxd_clean ? IDLE : WAIT_HIGH;
               end else
                  break_halves_left <= break_halves_left - 2'd1;
            end
         end else if (rec_sample_pulse) begin
            state <= next_state;
            case (state)
               START: begin
                  // A low edge alone is insufficient: validate mid-start.
                  if (rxd_clean)
                     state <= IDLE;
               end
               SEL_0: data_r[0] <= rxd_clean;
               SEL_1: data_r[1] <= rxd_clean;
               SEL_2: data_r[2] <= rxd_clean;
               SEL_3: data_r[3] <= rxd_clean;
               SEL_4: data_r[4] <= rxd_clean;
               SEL_5: data_r[5] <= rxd_clean;
               SEL_6: data_r[6] <= rxd_clean;
               DATA_END: data_r[last_bit] <= rxd_clean;
               PARITY: parity_err <= parity_bit ^ rxd_clean;
               STOP: begin
                  framing_err <= !rxd_clean;
                  if (frame_all_low && !rxd_clean) begin
                     break_halves_left <= !frame_format.stop_bit_count ? 2'd1 :
                         (frame_format.char_length == CHAR_5_BIT ? 2'd2 : 2'd3);
                     state <= BREAK_CHECK;
                  end else begin
                     push_dly <= 1'b1;
                     state <= rxd_clean ? IDLE : WAIT_HIGH;
                  end
               end
               default: state <= IDLE;
            endcase
         end
      end
   end
endmodule
