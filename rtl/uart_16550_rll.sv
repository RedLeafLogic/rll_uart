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

`ifndef SYN
timeunit 1ps;
timeprecision 1ps;
`endif

module uart_16550_rll
  import uart_package::*;
  (wb_bus wb_bus, uart_bus uart_bus);
   wire clk_i = wb_bus.clk_i;
   // Asynchronous assertion, two-clock synchronous release for the core.
   (* altera_attribute = "-name SYNCHRONIZER_IDENTIFICATION FORCED_IF_ASYNCHRONOUS" *)
   logic reset_meta;
   (* altera_attribute = "-name SYNCHRONIZER_IDENTIFICATION FORCED_IF_ASYNCHRONOUS" *)
   logic reset_released;
   always_ff @(posedge clk_i or negedge wb_bus.nrst_i) begin
      if (!wb_bus.nrst_i) begin
         reset_meta <= 1'b0;
         reset_released <= 1'b0;
      end else begin
         reset_meta <= 1'b1;
         reset_released <= reset_meta;
      end
   end
   wire nrst_i = reset_released;
   wire trans_buf_empty;
   wire rec_active;
   wire rec_sample_pulse, rec_bit_end;
   wire trans_clk_en, trans_half_en;
   wire txd_out, rxd_clean, rxd_clean_out;
   fifo_bus fifo_pop_trans(.clk_i(clk_i));
   fifo_bus fifo_push_rec(.clk_i(clk_i));
   u_reg_t u_reg;
   // The full register snapshot is exported for waveform inspection.
   wire unused_register_snapshot = ^u_reg;
   u_codec_t unused_trans_codec;

   assign uart_bus.stx_o = u_reg.modem_control_reg.loopback ? 1'b1 : txd_out;
   assign rxd_clean = u_reg.modem_control_reg.loopback ? txd_out : rxd_clean_out;

   uart_register u_register(
      .clk_i(clk_i), .nrst_i(nrst_i), .wb_bus(wb_bus), .uart_bus(uart_bus),
      .u_reg(u_reg), .fifo_pop_trans(fifo_pop_trans), .fifo_push_rec(fifo_push_rec),
      .trans_buf_empty(trans_buf_empty));
   uart_transmitter u_trans(
      .clk_i(clk_i), .nrst_i(nrst_i), .trans_clk_en(trans_clk_en),
      .trans_half_en(trans_half_en), .txd_out(txd_out), .fifo_pop(fifo_pop_trans),
      .line_format(u_reg.line_control_reg[5:0]),
      .break_control(u_reg.line_control_reg.break_control_bit),
      .trans_codec(unused_trans_codec), .trans_buf_empty(trans_buf_empty));
   uart_receiver u_rec(
      .clk_i(clk_i), .nrst_i(nrst_i), .rxd_clean(rxd_clean),
      .rec_sample_pulse(rec_sample_pulse), .rec_bit_end(rec_bit_end), .fifo_push(fifo_push_rec),
      .line_format(u_reg.line_control_reg[5:0]), .rec_active(rec_active));
   uart_baud u_baud(
      .clk_i(clk_i), .nrst_i(nrst_i), .baud_reg(u_reg.baud_reg),
      .rec_active(rec_active), .trans_active(!trans_buf_empty),
      .rec_sample_pulse(rec_sample_pulse), .rec_bit_end(rec_bit_end), .trans_clk_en(trans_clk_en),
      .trans_half_en(trans_half_en));
   uart_noize_shaver u_shaver(
      .clk_i(clk_i), .nrst_i(nrst_i), .rxd_i(uart_bus.srx_i),
      .rxd_clean(rxd_clean_out));
endmodule
