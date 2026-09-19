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

module uart_register
  import uart_package::*;
  (input wire clk_i,
   input wire nrst_i,
   wb_bus wb_bus,
   uart_bus uart_bus,
   output u_reg_t u_reg,
   fifo_bus fifo_pop_trans,
   fifo_bus fifo_push_rec,
   input wire trans_buf_empty);

   interrupt_enable_reg_t interrupt_enable_reg;
   interrupt_identification_reg_t interrupt_ident_reg;
   fifo_control_reg_t fifo_control_reg;
   modem_control_reg_t modem_control_reg;
   line_control_reg_t line_control_reg;
   line_status_reg_t line_status_reg;
   modem_status_reg_t modem_status_reg;
   interrupt_pending_reg_t interrupt_pending_reg;
   logic [7:0] scratch_reg;
   logic [7:0] baud_reg;
   // Assemble the exported snapshot from independent register/status signals.
   assign u_reg = {interrupt_enable_reg, interrupt_ident_reg, fifo_control_reg, modem_control_reg, line_control_reg, line_status_reg, modem_status_reg, interrupt_pending_reg, scratch_reg, baud_reg};

   fifo_bus fifo_pop_rec(.clk_i(clk_i));
   fifo_bus fifo_push_trans(.clk_i(clk_i));
   wire [2:0] reg_addr;
   wire [7:0] dat_i;
   logic [7:0] rdat;
   wire uart_stb;
`ifdef ALIGN_4B
   // Address-window selection belongs to the interconnect. Registers use
   // the low byte of each 32-bit word in this configuration.
   wire unused_bus_bits = ^{wb_bus.adr_i[31:5], wb_bus.adr_i[1:0], wb_bus.dat_i[31:8]};
   assign reg_addr = wb_bus.adr_i[4:2];
   assign uart_stb = nrst_i && wb_bus.cyc_i && wb_bus.stb_i && (&wb_bus.sel_i);
   assign dat_i = wb_bus.dat_i[7:0];
   assign wb_bus.dat_o = {24'b0, rdat};
`else
   wire unused_bus_bits = ^wb_bus.adr_i[31:3];
   assign reg_addr = wb_bus.adr_i[2:0];
   assign uart_stb = nrst_i && wb_bus.cyc_i && wb_bus.stb_i &&
                     wb_bus.sel_i[wb_bus.adr_i[1:0]];
   assign dat_i = wb_bus.dat_i[8*wb_bus.adr_i[1:0] +: 8];
   assign wb_bus.dat_o = {24'b0, rdat} << (8*wb_bus.adr_i[1:0]);
`endif
   assign wb_bus.ack_o = uart_stb;
   wire bus_read = uart_stb && !wb_bus.we_i;
   wire bus_write = uart_stb && wb_bus.we_i;
   wire dlab = line_control_reg.divisor_access;
   wire read_rbr = bus_read && reg_addr == 3'(UART_RXD) && !dlab;
   wire write_thr = bus_write && reg_addr == 3'(UART_TXD) && !dlab;
   wire write_baud = bus_write && reg_addr == 3'(UART_BAUD) && dlab;
   // This core retains an 8-bit divisor; DLAB offset 1 is reserved (zero).
   // Never corrupt IER when software attempts a DLM access.
   wire write_ier = bus_write && reg_addr == 3'(UART_INTERRUPT_ENABLE) && !dlab;
   wire read_iir = bus_read && reg_addr == 3'(UART_INTERRUPT_IDENT);
   wire write_fcr = bus_write && reg_addr == 3'(UART_FIFO_CONTROL);
   wire write_lcr = bus_write && reg_addr == 3'(UART_LINE_CONTROL);
   wire write_mcr = bus_write && reg_addr == 3'(UART_MODEM_CONTROL);
   wire read_lsr = bus_read && reg_addr == 3'(UART_LINE_STATUS);
   wire read_msr = bus_read && reg_addr == 3'(UART_MODEM_STATUS);
   wire write_scratch = bus_write && reg_addr == 3'(UART_SCRATCH);
   wire fifo_rec_reset = write_fcr && dat_i[1];
   wire fifo_trans_reset = write_fcr && dat_i[2];
   wire all_error_rec;
   wire unused_all_error_trans;

   uart_fifo fifo_rec(
      .clk_i(clk_i), .nrst_i(nrst_i), .clear(fifo_rec_reset),
      .clear_head_error(read_lsr),
      .almost_empty_level(fifo_control_reg.define_fifo_trigger_level),
      .fifo_pop(fifo_pop_rec), .fifo_push(fifo_push_rec), .all_error(all_error_rec));
   uart_fifo fifo_trans(
      .clk_i(clk_i), .nrst_i(nrst_i), .clear(fifo_trans_reset),
      .clear_head_error(1'b0),
      .almost_empty_level(fifo_control_reg.define_fifo_trigger_level),
      .fifo_pop(fifo_pop_trans), .fifo_push(fifo_push_trans),
      .all_error(unused_all_error_trans));

   assign fifo_pop_rec.pop = read_rbr;
   assign fifo_push_trans.push = write_thr;
   assign fifo_push_trans.push_dat = {3'b0, dat_i};

   always_comb begin
      rdat = 8'b0;
      if (uart_stb) begin
         case (reg_addr)
            3'd0: rdat = dlab ? baud_reg : fifo_pop_rec.pop_dat[7:0];
            3'd1: rdat = dlab ? 8'b0 : interrupt_enable_reg;
            3'd2: rdat = interrupt_ident_reg;
            3'd3: rdat = line_control_reg;
            3'd4: rdat = modem_control_reg;
            3'd5: rdat = line_status_reg;
            3'd6: rdat = modem_status_reg;
            3'd7: rdat = scratch_reg;
            default: ;
         endcase
      end
   end

   always_ff @(posedge clk_i or negedge nrst_i) begin
      if (!nrst_i) begin
         interrupt_enable_reg <= '0;
         fifo_control_reg <= fifo_control_reg_t'(8'hc0);
         line_control_reg <= line_control_reg_t'(8'h03);
         modem_control_reg <= '0;
         scratch_reg <= '0;
         baud_reg <= '0;
      end else begin
         if (write_ier)
            interrupt_enable_reg <= interrupt_enable_reg_t'({4'b0, dat_i[3:0]});
         if (write_fcr)
            fifo_control_reg <= fifo_control_reg_t'(dat_i);
         else
            fifo_control_reg[2:1] <= 2'b0;
         if (write_lcr)
            line_control_reg <= line_control_reg_t'(dat_i);
         if (write_mcr)
            modem_control_reg <= modem_control_reg_t'({3'b0, dat_i[4:0]});
         if (write_scratch)
            scratch_reg <= dat_i;
         if (write_baud)
            baud_reg <= dat_i;
      end
   end

   // Error acknowledgement belongs to the current FIFO head, not to the
   // 0->1 transition of an error bit shared by successive characters.
   logic head_error_seen;
   logic overrun_latched;
   wire [2:0] head_error = (!fifo_pop_rec.empty && !head_error_seen) ?
                           fifo_pop_rec.pop_dat[10:8] : 3'b0;
   wire overrun_event = fifo_push_rec.push && !fifo_push_rec.push_accept &&
                        !fifo_rec_reset;
   always_ff @(posedge clk_i or negedge nrst_i) begin
      if (!nrst_i) begin
         head_error_seen <= 1'b0;
         overrun_latched <= 1'b0;
      end else begin
         if (fifo_rec_reset || fifo_pop_rec.empty || fifo_pop_rec.pop_accept)
            head_error_seen <= 1'b0;
         else if (read_lsr)
            head_error_seen <= 1'b1;
         if (fifo_rec_reset)
            overrun_latched <= 1'b0;
         else
            overrun_latched <= (overrun_latched && !read_lsr) || overrun_event;
      end
   end
   assign line_status_reg.data_ready = !fifo_pop_rec.empty;
   assign line_status_reg.overrun_err = overrun_latched;
   assign line_status_reg.parity_err = head_error[2];
   assign line_status_reg.framing_err = head_error[1];
   assign line_status_reg.break_intr = head_error[0];
   assign line_status_reg.trans_fifo_empty = fifo_pop_trans.empty;
   assign line_status_reg.trans_empty = fifo_pop_trans.empty && trans_buf_empty;
   assign line_status_reg.all_error = all_error_rec;

   // Modem pins are active low. Only second-stage values feed the MSR.
   (* altera_attribute = "-name SYNCHRONIZER_IDENTIFICATION FORCED_IF_ASYNCHRONOUS" *)
   logic [3:0] modem_meta, modem_sync;
   logic [3:0] modem_previous, modem_delta;
   wire [3:0] modem_current = modem_control_reg.loopback ?
       {modem_control_reg.out2, modem_control_reg.out1,
        modem_control_reg.dtr, modem_control_reg.rts} : ~modem_sync;
   wire [3:0] modem_events = {
       modem_current[3] ^ modem_previous[3],
       modem_previous[2] && !modem_current[2],
       modem_current[1] ^ modem_previous[1],
       modem_current[0] ^ modem_previous[0]};
   always_ff @(posedge clk_i or negedge nrst_i) begin
      if (!nrst_i) begin
         modem_meta <= 4'hf;
         modem_sync <= 4'hf;
         modem_previous <= '0;
         modem_delta <= '0;
      end else begin
         modem_meta <= {uart_bus.dcd_i, uart_bus.ri_i, uart_bus.dsr_i, uart_bus.cts_i};
         modem_sync <= modem_meta;
         modem_previous <= modem_current;
         // A new event wins over a simultaneous read, independently per bit.
         modem_delta <= (modem_delta & {4{!read_msr}}) | modem_events;
      end
   end
   assign modem_status_reg = {modem_current, modem_delta};
   assign uart_bus.dtr_o = modem_control_reg.loopback || !modem_control_reg.dtr;
   assign uart_bus.rts_o = modem_control_reg.loopback || !modem_control_reg.rts;

   // Independent FIFO inactivity timer: four complete configured characters.
   // Half-bit units represent 5-bit + 1.5-stop formats without rounding.
   logic [11:0] timeout_divider;
   logic [6:0] timeout_halves;
   wire [11:0] half_period = {1'b0, baud_reg, 3'b0} + 12'd8;
   wire [6:0] stop_halves = !line_control_reg.stop_bit_count ? 7'd2 :
       (line_control_reg.char_length == CHAR_5_BIT ? 7'd3 : 7'd4);
   wire [6:0] frame_halves = 7'd12 +
       {4'b0, line_control_reg.char_length, 1'b0} +
       (line_control_reg.parity_enable ? 7'd2 : 7'd0) + stop_halves;
   wire [6:0] timeout_limit = frame_halves << 2;
   wire timeout_signal = !fifo_pop_rec.empty && timeout_halves == timeout_limit;
   always_ff @(posedge clk_i or negedge nrst_i) begin
      if (!nrst_i) begin
         timeout_divider <= '0;
         timeout_halves <= '0;
      end else if (fifo_rec_reset || fifo_pop_rec.empty || read_rbr ||
                   fifo_push_rec.push || write_baud || write_lcr) begin
         timeout_divider <= '0;
         timeout_halves <= '0;
      end else if (!timeout_signal) begin
         if (timeout_divider == half_period - 12'd1) begin
            timeout_divider <= '0;
            timeout_halves <= timeout_halves + 7'd1;
         end else
            timeout_divider <= timeout_divider + 12'd1;
      end
   end

   // THRE is an acknowledged event; the other sources are levels derived
   // from their own state. No vector-wide set can suppress another clear.
   logic thre_pending, tx_empty_previous;
   // Detect re-enabling on the IER write itself, not one cycle later:
   // a following IIR read must be able to acknowledge the visible event.
   wire thre_ack = read_iir &&
       interrupt_ident_reg.interrupt_identification == TRANS_REG_EMPTY;
   always_ff @(posedge clk_i or negedge nrst_i) begin
      if (!nrst_i) begin
         thre_pending <= 1'b1;
         tx_empty_previous <= 1'b1;
      end else begin
         tx_empty_previous <= fifo_pop_trans.empty;
         if (write_thr)
            thre_pending <= 1'b0;
         else if (fifo_trans_reset ||
                  (fifo_pop_trans.empty && !tx_empty_previous) ||
                  (fifo_pop_trans.empty && write_ier && dat_i[1] &&
                   !interrupt_enable_reg.trans_holding_reg_empty))
            thre_pending <= 1'b1;
         else if (thre_ack)
            thre_pending <= 1'b0;
      end
   end

   assign interrupt_pending_reg.receiver_line_status =
       (overrun_latched || (|head_error)) && interrupt_enable_reg.rec_line_status;
   assign interrupt_pending_reg.receiver_data_available =
       fifo_pop_rec.almost_full && interrupt_enable_reg.rec_data_available;
   assign interrupt_pending_reg.timeout_indication =
       timeout_signal && interrupt_enable_reg.rec_data_available;
   assign interrupt_pending_reg.transmitter_holding_register_empty =
       thre_pending && fifo_pop_trans.empty && interrupt_enable_reg.trans_holding_reg_empty;
   assign interrupt_pending_reg.modem_status =
       (|modem_delta) && interrupt_enable_reg.modem_status;
   assign wb_bus.intr_o = nrst_i && (|interrupt_pending_reg);

   always_comb begin
      // FIFO is always enabled in this core, independent of FCR[0].
      interrupt_ident_reg.ignored_74_value_hC = 4'hc;
      if (interrupt_pending_reg.receiver_line_status)
         interrupt_ident_reg.interrupt_identification = REC_LINE_STATUS;
      else if (interrupt_pending_reg.receiver_data_available)
         interrupt_ident_reg.interrupt_identification = REC_DATA_AVAILABLE;
      else if (interrupt_pending_reg.timeout_indication)
         interrupt_ident_reg.interrupt_identification = TIME_OUT;
      else if (interrupt_pending_reg.transmitter_holding_register_empty)
         interrupt_ident_reg.interrupt_identification = TRANS_REG_EMPTY;
      else if (interrupt_pending_reg.modem_status)
         interrupt_ident_reg.interrupt_identification = MODEM_STATUS;
      else
         interrupt_ident_reg.interrupt_identification = NO_INTERRUPT;
   end
endmodule
