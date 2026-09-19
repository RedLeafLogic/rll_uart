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

module uart_baud
  (input wire clk_i,
   input wire nrst_i,
   input wire [7:0] baud_reg,
   input wire rec_active,
   input wire trans_active,
   output wire rec_sample_pulse,
   output wire rec_bit_end,
   output wire trans_clk_en,
   output wire trans_half_en);

   // Preserve this core's existing divisor convention: Tbit = 16*(B+1).
   // Capture the divisor while idle so software cannot shorten an active bit.
   logic [7:0] rec_baud, trans_baud;
   logic [12:0] rec_count, trans_count;
   wire [12:0] rec_period = {1'b0, rec_baud, 4'b0} + 13'd16;
   wire [12:0] trans_period = {1'b0, trans_baud, 4'b0} + 13'd16;
   wire [12:0] rec_half = rec_period >> 1;
   wire [12:0] trans_half = trans_period >> 1;

   assign rec_sample_pulse = rec_active && rec_count == rec_half - 13'd1;
   assign rec_bit_end = rec_active && rec_count == rec_period - 13'd1;
   assign trans_clk_en = trans_active && trans_count == trans_period - 13'd1;
   assign trans_half_en = trans_active && trans_count == trans_half - 13'd1;

   always_ff @(posedge clk_i or negedge nrst_i) begin
      if (!nrst_i) begin
         rec_baud <= '0;
         trans_baud <= '0;
         rec_count <= '0;
         trans_count <= '0;
      end else begin
         if (!rec_active) begin
            rec_baud <= baud_reg;
            rec_count <= '0;
         end else if (rec_count == rec_period - 13'd1)
            rec_count <= '0;
         else
            rec_count <= rec_count + 13'd1;
         if (!trans_active) begin
            trans_baud <= baud_reg;
            trans_count <= '0;
         end else if (trans_clk_en)
            trans_count <= '0;
         else
            trans_count <= trans_count + 13'd1;
      end
   end
endmodule
