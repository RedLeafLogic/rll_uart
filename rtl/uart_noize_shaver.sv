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
