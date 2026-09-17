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

// State denotes the bit currently on the wire (TX) or being sampled (RX).
module uart_codec_state
  import uart_package::*;
  (input codec_state_t state,
   input char_length_t char_length,
   input wire parity_enable,
   input wire stop_bit_count,
   output codec_state_t next_state);
   always_comb begin
      case (state)
         IDLE: next_state = START;
         START: next_state = SEL_0;
         SEL_0: next_state = SEL_1;
         SEL_1: next_state = SEL_2;
         SEL_2: next_state = SEL_3;
         SEL_3: next_state = char_length == CHAR_5_BIT ? DATA_END : SEL_4;
         SEL_4: next_state = char_length == CHAR_6_BIT ? DATA_END : SEL_5;
         SEL_5: next_state = char_length == CHAR_7_BIT ? DATA_END : SEL_6;
         SEL_6: next_state = DATA_END;
         DATA_END: next_state = parity_enable ? PARITY : STOP;
         PARITY: next_state = STOP;
         STOP: next_state = stop_bit_count ? STOP_EXTRA : IDLE;
         STOP_EXTRA: next_state = IDLE;
         default: next_state = IDLE;
      endcase
   end
endmodule
