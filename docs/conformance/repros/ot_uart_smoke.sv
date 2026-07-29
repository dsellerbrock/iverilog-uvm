// Smoke test: drive the real OpenTitan UART IP over TL-UL and watch a byte
// come out of cio_tx_o. Unmodified OpenTitan RTL; only this file is ours.
module ot_uart_smoke;
  import tlul_pkg::*;
  import uart_reg_pkg::*;

  localparam int unsigned NCO = 16'h0800; // ~1/32 of clk per bit tick

  logic clk = 0, rst_n = 0;
  always #5 clk = ~clk;

  tl_h2d_t tl_req_raw, tl_req;
  tl_d2h_t tl_rsp;

  // Generate the TL-UL command/data integrity the register block checks.
  tlul_cmd_intg_gen #(.EnableDataIntgGen(1'b1)) u_intg (
    .tl_i(tl_req_raw),
    .tl_o(tl_req)
  );

  logic cio_tx, cio_tx_en;
  prim_alert_pkg::alert_rx_t [NumAlerts-1:0] alert_rx;

  uart dut (
    .clk_i            (clk),
    .rst_ni           (rst_n),
    .tl_i             (tl_req),
    .tl_o             (tl_rsp),
    .alert_rx_i       (alert_rx),
    .alert_tx_o       (),
    .racl_policies_i  ('0),
    .racl_error_o     (),
    .lsio_trigger_o   (),
    .cio_rx_i         (1'b1),
    .cio_tx_o         (cio_tx),
    .cio_tx_en_o      (cio_tx_en),
    .intr_tx_watermark_o (), .intr_tx_empty_o (), .intr_rx_watermark_o (),
    .intr_tx_done_o (), .intr_rx_overflow_o (), .intr_rx_frame_err_o (),
    .intr_rx_break_err_o (), .intr_rx_timeout_o (), .intr_rx_parity_err_o ()
  );

  initial begin
    alert_rx = '{default: prim_alert_pkg::ALERT_RX_DEFAULT};
  end

  int errors = 0;

  task automatic tl_write(input logic [31:0] addr, input logic [31:0] data);
    @(posedge clk);
    tl_req_raw          <= TL_H2D_DEFAULT;
    tl_req_raw.a_valid  <= 1'b1;
    tl_req_raw.a_opcode <= PutFullData;
    tl_req_raw.a_size   <= 2'h2;
    tl_req_raw.a_mask   <= 4'hf;
    tl_req_raw.a_source <= '0;
    tl_req_raw.a_address<= addr;
    tl_req_raw.a_data   <= data;
    tl_req_raw.d_ready  <= 1'b1;
    // wait for the address phase to be accepted
    do @(posedge clk); while (!tl_rsp.a_ready);
    tl_req_raw.a_valid <= 1'b0;
    // wait for the response
    do @(posedge clk); while (!tl_rsp.d_valid);
    if (tl_rsp.d_error) begin
      $display("ERROR: TL-UL write to 0x%02h returned d_error", addr);
      errors++;
    end
    @(posedge clk);
    tl_req_raw.d_ready <= 1'b0;
  endtask

  task automatic tl_read(input logic [31:0] addr, output logic [31:0] data);
    @(posedge clk);
    tl_req_raw          <= TL_H2D_DEFAULT;
    tl_req_raw.a_valid  <= 1'b1;
    tl_req_raw.a_opcode <= Get;
    tl_req_raw.a_size   <= 2'h2;
    tl_req_raw.a_mask   <= 4'hf;
    tl_req_raw.a_source <= '0;
    tl_req_raw.a_address<= addr;
    tl_req_raw.a_data   <= '0;
    tl_req_raw.d_ready  <= 1'b1;
    do @(posedge clk); while (!tl_rsp.a_ready);
    tl_req_raw.a_valid <= 1'b0;
    do @(posedge clk); while (!tl_rsp.d_valid);
    data = tl_rsp.d_data;
    if (tl_rsp.d_error) begin
      $display("ERROR: TL-UL read from 0x%02h returned d_error", addr);
      errors++;
    end
    @(posedge clk);
    tl_req_raw.d_ready <= 1'b0;
  endtask

  // Count falling edges on cio_tx_o -- a transmitted byte must produce at
  // least the start bit plus some data transitions.
  int tx_edges = 0;
  always @(negedge cio_tx) if (rst_n) tx_edges++;

  logic [31:0] rdata;

  initial begin
    tl_req_raw = TL_H2D_DEFAULT;
    repeat (5) @(posedge clk);
    rst_n = 1;
    repeat (10) @(posedge clk);

    // Enable TX with a baud rate divisor.
    tl_write(UART_CTRL_OFFSET, {NCO, 16'h0001});

    // Read CTRL back and check it stuck.
    tl_read(UART_CTRL_OFFSET, rdata);
    if (rdata !== {NCO, 16'h0001}) begin
      $display("ERROR: CTRL readback mismatch: got 0x%08h want 0x%08h",
               rdata, {NCO, 16'h0001});
      errors++;
    end else begin
      $display("PASS: CTRL readback 0x%08h", rdata);
    end

    // Push a byte into the TX fifo.
    tl_write(UART_WDATA_OFFSET, 32'h0000_0055);

    // Let it shift out.
    repeat (4000) @(posedge clk);

    if (cio_tx_en !== 1'b1) begin
      $display("ERROR: cio_tx_en_o not asserted after enabling TX");
      errors++;
    end
    if (tx_edges == 0) begin
      $display("ERROR: no activity seen on cio_tx_o");
      errors++;
    end else begin
      $display("PASS: cio_tx_o toggled (%0d falling edges)", tx_edges);
    end

    if (errors == 0) $display("SMOKE TEST PASSED");
    else             $display("SMOKE TEST FAILED (%0d errors)", errors);
    $finish;
  end

  initial begin
    #10_000_000;
    $display("ERROR: timeout");
    $finish;
  end
endmodule
