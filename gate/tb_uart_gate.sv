`timescale 1ns/1ps

module tb_uart_gate;
   localparam time CLK_PERIOD = 10ns;
   localparam logic [7:0] TEST_DATA = 8'hA5;

   logic        clk_i = 1'b0;
   logic        nrst_i = 1'b0;
   logic [15:0] adr_i = '0;
   logic [31:0] dat_i = '0;
   wire  [31:0] dat_o;
   logic        we_i = 1'b0;
   logic [3:0]  sel_i = 4'b0000;
   logic        stb_i = 1'b0;
   wire         ack_o;
   logic        cyc_i = 1'b0;
   wire         intr_o;
   wire         stx_o;
   wire         rts_o;
   wire         dtr_o;
   wire         srx_i;
   logic        cts_i = 1'b1;
   logic        dsr_i = 1'b1;
   logic        ri_i = 1'b1;
   logic        dcd_i = 1'b1;

   // Representative serial loopback at the device pins.
   assign srx_i = stx_o;

   uart_top dut (
      .clk_i, .nrst_i, .adr_i, .dat_i, .dat_o, .we_i, .sel_i,
      .stb_i, .ack_o, .cyc_i, .intr_o, .stx_o, .rts_o, .dtr_o,
      .srx_i, .cts_i, .dsr_i, .ri_i, .dcd_i
   );

   always #(CLK_PERIOD / 2) clk_i = ~clk_i;

   task automatic wb_idle;
      begin
         adr_i = '0;
         dat_i = '0;
         we_i  = 1'b0;
         sel_i = 4'b0000;
         stb_i = 1'b0;
         cyc_i = 1'b0;
      end
   endtask

   task automatic wait_for_ack;
      integer cycles;
      begin
         cycles = 0;
         while (ack_o !== 1'b1 && cycles < 20) begin
            @(posedge clk_i);
            #2ns;
            cycles++;
         end
         if (ack_o !== 1'b1) begin
            $error("Wishbone acknowledge timeout at address 0x%04h", adr_i);
            $fatal(1);
         end
      end
   endtask

   task automatic wb_write(input logic [2:0] reg_index,
                           input logic [7:0] value);
      begin
         @(negedge clk_i);
         adr_i = {11'b0, reg_index, 2'b00};
         dat_i = {24'b0, value};
         we_i  = 1'b1;
         sel_i = 4'b1111;
         stb_i = 1'b1;
         cyc_i = 1'b1;
         wait_for_ack();
         @(negedge clk_i);
         wb_idle();
      end
   endtask

   task automatic wb_read(input logic [2:0] reg_index,
                          output logic [7:0] value);
      begin
         @(negedge clk_i);
         adr_i = {11'b0, reg_index, 2'b00};
         dat_i = '0;
         we_i  = 1'b0;
         sel_i = 4'b1111;
         stb_i = 1'b1;
         cyc_i = 1'b1;
         // ACK and read data are combinational. Capture RBR before the next
         // rising edge pops the receive FIFO entry.
         #2ns;
         if (ack_o !== 1'b1) begin
            $error("Wishbone read acknowledge missing at address 0x%04h", adr_i);
            $fatal(1);
         end
         value = dat_o[7:0];
         @(posedge clk_i);
         @(negedge clk_i);
         wb_idle();
      end
   endtask

   initial begin : representative_test
      logic [7:0] read_data;
      logic [7:0] line_status;
      integer poll_count;

      $timeformat(-9, 3, " ns", 12);
      wb_idle();

      // Asynchronous assertion, followed by a clocked release interval.
      #(10 * CLK_PERIOD);
      nrst_i = 1'b1;
      repeat (8) @(posedge clk_i);

      // LCR.DLAB=1, divisor=3, then 8 data bits/no parity/1 stop bit.
      wb_write(3, 8'h83);
      wb_write(0, 8'h03);
      wb_write(3, 8'h03);

      // Transmit one representative byte through the pin-level loopback.
      wb_write(0, TEST_DATA);

      poll_count = 0;
      line_status = '0;
      while (!line_status[0] && poll_count < 4000) begin
         wb_read(5, line_status);
         poll_count++;
      end
      if (!line_status[0]) begin
         $error("RX data-ready timeout; LSR=0x%02h", line_status);
         $fatal(1);
      end
      if (line_status[4:1] !== 4'b0000) begin
         $error("Unexpected RX error flags; LSR=0x%02h", line_status);
         $fatal(1);
      end

      wb_read(0, read_data);
      if (read_data !== TEST_DATA) begin
         $error("Loopback mismatch: expected 0x%02h, received 0x%02h",
                TEST_DATA, read_data);
         $fatal(1);
      end

      $display("POST-FIT FUNCTIONAL REPRESENTATIVE TEST PASS: received 0x%02h at %0t",
               read_data, $time);
      #(10 * CLK_PERIOD);
      $finish;
   end

   initial begin : global_timeout
      #200us;
      $error("Global gate simulation timeout");
      $fatal(1);
   end
endmodule
