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

module uart_noize_shaver
  (input wire clk_i,
   input wire nrst_i,
   input wire rxd_i,
   output wire rxd_clean);

   // Only the final synchronizer stage feeds functional logic.
   (* altera_attribute = "-name SYNCHRONIZER_IDENTIFICATION FORCED_IF_ASYNCHRONOUS" *)
   logic [1:0] rxd_sync;
   logic [2:0] samples;
   always_ff @(posedge clk_i or negedge nrst_i) begin
      if (!nrst_i) begin
         rxd_sync <= 2'b11;
         samples <= 3'b111;
      end else begin
         rxd_sync <= {rxd_sync[0], rxd_i};
         samples <= {samples[1:0], rxd_sync[1]};
      end
   end
   // Symmetric three-sample majority, evaluated every system clock.
   // The shortest supported bit is sixteen clocks (baud_reg = 0).
   assign rxd_clean = (samples[2] & samples[1]) |
                      (samples[2] & samples[0]) |
                      (samples[1] & samples[0]);
endmodule
