/* Self-checking UART regression. Included inside top.test_pat(). */

// At baud_reg=64 a 7-bit character takes at most 11*16*65 clocks.
// This margin lets all eight queued characters reach the receive FIFO.
#(STEP*100);
UART_R = '0;

$display("configure 7-bit, no parity, RX trigger 14");
UART_R.fifo_control_reg.define_fifo_trigger_level = BYTE_14;
wb_DUT.write({24'h0, UART_R.fifo_control_reg}, UART_FIFO_CONTROL);
wb_BENCH.write({24'h0, UART_R.fifo_control_reg}, UART_FIFO_CONTROL);

UART_R.line_control_reg.divisor_access = 1'b1;
UART_R.baud_reg = 8'd64;
wb_DUT.write({24'h0, UART_R.line_control_reg}, UART_LINE_CONTROL);
wb_DUT.write({24'h0, UART_R.baud_reg}, UART_BAUD);
wb_BENCH.write({24'h0, UART_R.line_control_reg}, UART_LINE_CONTROL);
wb_BENCH.write({24'h0, UART_R.baud_reg}, UART_BAUD);

UART_R.line_control_reg.divisor_access = 1'b0;
UART_R.line_control_reg.char_length = CHAR_7_BIT;
UART_R.line_control_reg.parity_enable = 1'b0;
UART_R.line_control_reg.even_parity = 1'b0;
wb_DUT.write({24'h0, UART_R.line_control_reg}, UART_LINE_CONTROL);
wb_BENCH.write({24'h0, UART_R.line_control_reg}, UART_LINE_CONTROL);

$display("test 7-bit no-parity transfer");
for (i=0; i<8; i+=1)
   wb_DUT.write(32'(1 << i), UART_TXD);
#6ms;
for (i=0; i<8; i+=1) begin
   wb_BENCH.read(rdat, UART_RXD);
   if (rdat[7:0] !== (8'(1 << i) & 8'h7f)) begin
      $error("no-parity data[%0d]: expected=%02x actual=%02x", i,
             (8'(1 << i) & 8'h7f), rdat[7:0]);
      $fatal(1);
   end
end
wb_BENCH.read(rdat, UART_LINE_STATUS);
if (rdat[3:2] !== 2'b00) begin
   $error("unexpected no-parity PE/FE: LSR=%02x", rdat[7:0]);
   $fatal(1);
end

$display("test even parity transfer");
UART_R.fifo_control_reg.transmitter_fifo_reset = 1'b1;
UART_R.fifo_control_reg.receiver_fifo_reset = 1'b1;
wb_DUT.write({24'h0, UART_R.fifo_control_reg}, UART_FIFO_CONTROL);
wb_BENCH.write({24'h0, UART_R.fifo_control_reg}, UART_FIFO_CONTROL);
UART_R.fifo_control_reg.transmitter_fifo_reset = 1'b0;
UART_R.fifo_control_reg.receiver_fifo_reset = 1'b0;
UART_R.line_control_reg.parity_enable = 1'b1;
UART_R.line_control_reg.even_parity = 1'b1;
wb_DUT.write({24'h0, UART_R.line_control_reg}, UART_LINE_CONTROL);
wb_BENCH.write({24'h0, UART_R.line_control_reg}, UART_LINE_CONTROL);
for (i=0; i<8; i+=1)
   wb_DUT.write(32'(8'h55 ^ i), UART_TXD);
#6ms;
for (i=0; i<8; i+=1) begin
   wb_BENCH.read(rdat, UART_LINE_STATUS);
   if (rdat[3:2] !== 2'b00) begin
      $error("even-parity PE/FE[%0d]: LSR=%02x", i, rdat[7:0]);
      $fatal(1);
   end
   wb_BENCH.read(rdat, UART_RXD);
   if (rdat[7:0] !== (8'(8'h55 ^ i) & 8'h7f)) begin
      $error("even-parity data[%0d]: expected=%02x actual=%02x", i,
             (8'(8'h55 ^ i) & 8'h7f), rdat[7:0]);
      $fatal(1);
   end
end

$display("test odd parity transfer");
UART_R.line_control_reg.even_parity = 1'b0;
wb_DUT.write({24'h0, UART_R.line_control_reg}, UART_LINE_CONTROL);
wb_BENCH.write({24'h0, UART_R.line_control_reg}, UART_LINE_CONTROL);
for (i=0; i<8; i+=1)
   wb_DUT.write(32'(8'h2a ^ i), UART_TXD);
#6ms;
for (i=0; i<8; i+=1) begin
   wb_BENCH.read(rdat, UART_LINE_STATUS);
   if (rdat[3:2] !== 2'b00) begin
      $error("odd-parity PE/FE[%0d]: LSR=%02x", i, rdat[7:0]);
      $fatal(1);
   end
   wb_BENCH.read(rdat, UART_RXD);
   if (rdat[7:0] !== (8'(8'h2a ^ i) & 8'h7f)) begin
      $error("odd-parity data[%0d]: expected=%02x actual=%02x", i,
             (8'(8'h2a ^ i) & 8'h7f), rdat[7:0]);
      $fatal(1);
   end
end

$display("test receive timeout interrupt");
UART_R.fifo_control_reg.transmitter_fifo_reset = 1'b1;
UART_R.fifo_control_reg.receiver_fifo_reset = 1'b1;
wb_DUT.write({24'h0, UART_R.fifo_control_reg}, UART_FIFO_CONTROL);
wb_BENCH.write({24'h0, UART_R.fifo_control_reg}, UART_FIFO_CONTROL);
UART_R.fifo_control_reg.transmitter_fifo_reset = 1'b0;
UART_R.fifo_control_reg.receiver_fifo_reset = 1'b0;
UART_R.interrupt_enable_reg = '0;
UART_R.interrupt_enable_reg.rec_data_available = 1'b1;
wb_DUT.write({24'h0, UART_R.interrupt_enable_reg}, UART_INTERRUPT_ENABLE);
for (i=0; i<4; i+=1)
   wb_BENCH.write(32'(8'h30 + i), UART_TXD);
#6ms;
if (intr_o !== 1'b1) begin
   $error("timeout interrupt did not assert");
   $fatal(1);
end
wb_DUT.read(rdat, UART_INTERRUPT_IDENT);
if (rdat[3:0] !== TIME_OUT) begin
   $error("expected timeout IIR=%x actual=%02x", TIME_OUT, rdat[7:0]);
   $fatal(1);
end
wb_DUT.read(rdat, UART_RXD);
if (rdat[7:0] !== 8'h30) begin
   $error("timeout FIFO data expected=30 actual=%02x", rdat[7:0]);
   $fatal(1);
end
wb_DUT.read(rdat, UART_INTERRUPT_IDENT);
if (rdat[3:0] !== NO_INTERRUPT) begin
   $error("timeout interrupt not cleared after RBR read: IIR=%02x", rdat[7:0]);
   $fatal(1);
end

$display("test 5-bit data with 1.5 stop bits and frame duration");
UART_R.fifo_control_reg.transmitter_fifo_reset = 1'b1;
UART_R.fifo_control_reg.receiver_fifo_reset = 1'b1;
wb_DUT.write({24'h0, UART_R.fifo_control_reg}, UART_FIFO_CONTROL);
wb_BENCH.write({24'h0, UART_R.fifo_control_reg}, UART_FIFO_CONTROL);
UART_R.fifo_control_reg.transmitter_fifo_reset = 1'b0;
UART_R.fifo_control_reg.receiver_fifo_reset = 1'b0;
UART_R.line_control_reg.char_length = CHAR_5_BIT;
UART_R.line_control_reg.parity_enable = 1'b0;
UART_R.line_control_reg.stop_bit_count = 1'b1;
wb_DUT.write({24'h0, UART_R.line_control_reg}, UART_LINE_CONTROL);
wb_BENCH.write({24'h0, UART_R.line_control_reg}, UART_LINE_CONTROL);
fork
   begin
      @(negedge uart_bus_DUT.stx_o);
      frame_start = $time;
      @(negedge uart_bus_DUT.stx_o);
      frame_end = $time;
      frame_time = frame_end - frame_start;
   end
   begin
      wb_DUT.write(32'h1f, UART_TXD);
      wb_DUT.write(32'h1f, UART_TXD);
   end
join
if (frame_time < 389us || frame_time > 391us) begin
   $error("5-bit/1.5-stop frame expected about 390us, actual=%0t", frame_time);
   $fatal(1);
end
#1ms;
for (i=0; i<2; i+=1) begin
   wb_BENCH.read(rdat, UART_LINE_STATUS);
   if (rdat[3] !== 1'b0) begin
      $error("5-bit/1.5-stop framing error: LSR=%02x", rdat[7:0]);
      $fatal(1);
   end
   wb_BENCH.read(rdat, UART_RXD);
   if (rdat[7:0] !== 8'h1f) begin
      $error("5-bit data expected=1f actual=%02x", rdat[7:0]);
      $fatal(1);
   end
end

$display("test 6-bit data with 2 stop bits");
UART_R.line_control_reg.char_length = CHAR_6_BIT;
UART_R.line_control_reg.stop_bit_count = 1'b1;
wb_DUT.write({24'h0, UART_R.line_control_reg}, UART_LINE_CONTROL);
wb_BENCH.write({24'h0, UART_R.line_control_reg}, UART_LINE_CONTROL);
for (i=0; i<4; i+=1)
   wb_DUT.write(32'(8'h31 + i), UART_TXD);
#3ms;
for (i=0; i<4; i+=1) begin
   wb_BENCH.read(rdat, UART_LINE_STATUS);
   if (rdat[3] !== 1'b0) begin
      $error("6-bit/2-stop framing error[%0d]: LSR=%02x", i, rdat[7:0]);
      $fatal(1);
   end
   wb_BENCH.read(rdat, UART_RXD);
   if (rdat[7:0] !== 8'(8'h31 + i)) begin
      $error("6-bit data[%0d] expected=%02x actual=%02x", i,
             8'(8'h31 + i), rdat[7:0]);
      $fatal(1);
   end
end

$display("test 8-bit data with 2 stop bits and frame duration");
UART_R.line_control_reg.char_length = CHAR_8_BIT;
UART_R.line_control_reg.stop_bit_count = 1'b1;
wb_DUT.write({24'h0, UART_R.line_control_reg}, UART_LINE_CONTROL);
wb_BENCH.write({24'h0, UART_R.line_control_reg}, UART_LINE_CONTROL);
fork
   begin
      @(negedge uart_bus_DUT.stx_o);
      frame_start = $time;
      @(negedge uart_bus_DUT.stx_o);
      frame_end = $time;
      frame_time = frame_end - frame_start;
   end
   begin
      wb_DUT.write(32'hff, UART_TXD);
      wb_DUT.write(32'hff, UART_TXD);
   end
join
if (frame_time < 571us || frame_time > 573us) begin
   $error("8-bit/2-stop frame expected about 572us, actual=%0t", frame_time);
   $fatal(1);
end
#1ms;
for (i=0; i<2; i+=1) begin
   wb_BENCH.read(rdat, UART_LINE_STATUS);
   if (rdat[3] !== 1'b0) begin
      $error("8-bit/2-stop framing error: LSR=%02x", rdat[7:0]);
      $fatal(1);
   end
   wb_BENCH.read(rdat, UART_RXD);
   if (rdat[7:0] !== 8'hff) begin
      $error("8-bit data expected=ff actual=%02x", rdat[7:0]);
      $fatal(1);
   end
end

$display("test RX FIFO full and overrun preservation");
UART_R.fifo_control_reg.transmitter_fifo_reset = 1'b1;
UART_R.fifo_control_reg.receiver_fifo_reset = 1'b1;
wb_DUT.write({24'h0, UART_R.fifo_control_reg}, UART_FIFO_CONTROL);
wb_BENCH.write({24'h0, UART_R.fifo_control_reg}, UART_FIFO_CONTROL);
UART_R.fifo_control_reg.transmitter_fifo_reset = 1'b0;
UART_R.fifo_control_reg.receiver_fifo_reset = 1'b0;
UART_R.line_control_reg.char_length = CHAR_8_BIT;
UART_R.line_control_reg.stop_bit_count = 1'b0;
UART_R.line_control_reg.parity_enable = 1'b0;
wb_DUT.write({24'h0, UART_R.line_control_reg}, UART_LINE_CONTROL);
wb_BENCH.write({24'h0, UART_R.line_control_reg}, UART_LINE_CONTROL);
for (i=0; i<17; i+=1)
   wb_BENCH.write(32'(8'h80 + i), UART_TXD);
#12ms;
wb_DUT.read(rdat, UART_LINE_STATUS);
if (rdat[1] !== 1'b1 || rdat[0] !== 1'b1) begin
   $error("expected overrun and data-ready at full FIFO: LSR=%02x", rdat[7:0]);
   $fatal(1);
end
for (i=0; i<16; i+=1) begin
   wb_DUT.read(rdat, UART_RXD);
   if (rdat[7:0] !== 8'(8'h80 + i)) begin
      $error("full FIFO data[%0d] expected=%02x actual=%02x", i,
             8'(8'h80 + i), rdat[7:0]);
      $fatal(1);
   end
end
wb_DUT.read(rdat, UART_LINE_STATUS);
if (rdat[1:0] !== 2'b00) begin
   $error("FIFO did not empty or overrun did not clear: LSR=%02x", rdat[7:0]);
   $fatal(1);
end

$display("test break detection and single-character capture");
UART_R.fifo_control_reg.receiver_fifo_reset = 1'b1;
wb_DUT.write({24'h0, UART_R.fifo_control_reg}, UART_FIFO_CONTROL);
UART_R.fifo_control_reg.receiver_fifo_reset = 1'b0;
UART_R.line_control_reg.break_control_bit = 1'b1;
wb_BENCH.write({24'h0, UART_R.line_control_reg}, UART_LINE_CONTROL);
#2ms;
wb_DUT.read(rdat, UART_LINE_STATUS);
if (rdat[4:3] !== 2'b11 || rdat[0] !== 1'b1) begin
   $error("expected BI, FE and data-ready during break: LSR=%02x", rdat[7:0]);
   $fatal(1);
end
wb_DUT.read(rdat, UART_RXD);
if (rdat[7:0] !== 8'h00) begin
   $error("break character expected=00 actual=%02x", rdat[7:0]);
   $fatal(1);
end
#1ms;
wb_DUT.read(rdat, UART_LINE_STATUS);
if (rdat[0] !== 1'b0) begin
   $error("continuous break produced more than one character: LSR=%02x", rdat[7:0]);
   $fatal(1);
end
UART_R.line_control_reg.break_control_bit = 1'b0;
wb_BENCH.write({24'h0, UART_R.line_control_reg}, UART_LINE_CONTROL);
#200us;

$display("test modem status, delta accumulation and modem interrupt");
UART_R.interrupt_enable_reg = '0;
UART_R.interrupt_enable_reg.modem_status = 1'b1;
wb_DUT.write({24'h0, UART_R.interrupt_enable_reg}, UART_INTERRUPT_ENABLE);
wb_DUT.read(rdat, UART_MODEM_STATUS); // clear changes caused by initial pin levels
UART_R.modem_control_reg = '0;
UART_R.modem_control_reg.rts = 1'b1;
UART_R.modem_control_reg.dtr = 1'b1;
wb_BENCH.write({24'h0, UART_R.modem_control_reg}, UART_MODEM_CONTROL);
ri = 1'b1;
dcd = 1'b1;
#(STEP*20);
if (intr_o !== 1'b1) begin
   $error("modem interrupt did not assert");
   $fatal(1);
end
wb_DUT.read(rdat, UART_INTERRUPT_IDENT);
if (rdat[3:0] !== MODEM_STATUS) begin
   $error("expected modem IIR=%x actual=%02x", MODEM_STATUS, rdat[7:0]);
   $fatal(1);
end
wb_DUT.read(rdat, UART_MODEM_STATUS);
if (rdat[7:0] !== 8'h3f) begin
   $error("expected accumulated modem status 3f actual=%02x", rdat[7:0]);
   $fatal(1);
end
#(STEP*10);
if (intr_o !== 1'b0) begin
   $error("modem interrupt did not clear after MSR read");
   $fatal(1);
end

$display("test simultaneous line-status and modem interrupts");
UART_R.fifo_control_reg.receiver_fifo_reset = 1'b1;
wb_DUT.write({24'h0, UART_R.fifo_control_reg}, UART_FIFO_CONTROL);
UART_R.fifo_control_reg.receiver_fifo_reset = 1'b0;
wb_DUT.read(rdat, UART_MODEM_STATUS);
UART_R.interrupt_enable_reg = '0;
UART_R.interrupt_enable_reg.rec_line_status = 1'b1;
UART_R.interrupt_enable_reg.modem_status = 1'b1;
wb_DUT.write({24'h0, UART_R.interrupt_enable_reg}, UART_INTERRUPT_ENABLE);
UART_R.modem_control_reg.rts = 1'b0;
wb_BENCH.write({24'h0, UART_R.modem_control_reg}, UART_MODEM_CONTROL);
UART_R.line_control_reg.break_control_bit = 1'b1;
wb_BENCH.write({24'h0, UART_R.line_control_reg}, UART_LINE_CONTROL);
#2ms;
wb_DUT.read(rdat, UART_INTERRUPT_IDENT);
if (rdat[3:0] !== REC_LINE_STATUS) begin
   $error("line-status did not win interrupt priority: IIR=%02x", rdat[7:0]);
   $fatal(1);
end
wb_DUT.read(rdat, UART_LINE_STATUS);
wb_DUT.read(rdat, UART_INTERRUPT_IDENT);
if (rdat[3:0] !== MODEM_STATUS) begin
   $error("modem interrupt was lost while clearing line-status: IIR=%02x", rdat[7:0]);
   $fatal(1);
end
wb_DUT.read(rdat, UART_MODEM_STATUS);
wb_DUT.read(rdat, UART_RXD);
UART_R.line_control_reg.break_control_bit = 1'b0;
wb_BENCH.write({24'h0, UART_R.line_control_reg}, UART_LINE_CONTROL);
#200us;
wb_DUT.read(rdat, UART_INTERRUPT_IDENT);
if (rdat[3:0] !== NO_INTERRUPT) begin
   $error("interrupts did not clear after servicing both causes: IIR=%02x", rdat[7:0]);
   $fatal(1);
end

$display("UART SELF-CHECK PASS");
$fdisplay(file_a, "UART SELF-CHECK PASS");
#(STEP*20);
