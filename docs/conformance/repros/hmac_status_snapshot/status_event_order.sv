// Pinned hmac_scoreboard.sv refreshes hmac_fifo_depth one clocking-block
// posedge (@cb) after a counter change, while the status prediction runs
// after the TL monitor's @(mon_cb) wake-up plus an analysis-FIFO hop. Both
// clocking events trigger in the Observed region (IEEE 1800-2017 14.13) and
// their waiters resume in Active in unspecified order (4.5, 4.7), so the
// cached prediction is a legal race. The live-counter form is order-free.
interface cif(input logic clk);
  clocking cb @(posedge clk); endclocking
  clocking cbn @(negedge clk); endclocking
endinterface

module status_event_order;
  logic clk = 0;
  always #5 clk = ~clk;
  cif clk_rst(clk);
  cif tl(clk);

  int wr = 1, rd = 0;
  bit [5:0] cached_depth = 1;
  mailbox #(int) a_chan = new;

  function automatic logic [31:0] status(input bit [5:0] depth);
    return ((depth == 0) << 1) | ((depth == 32) << 2) | (depth << 4);
  endfunction

  // Scoreboard FIFO-status loop: refresh one posedge after a counter change.
  initial forever begin
    @(wr, rd);
    @(clk_rst.cb);
    cached_depth = wr - rd;
  end

  // DUT reads the last FIFO word on a negedge; SW status read accepted at the next posedge.
  initial begin
    @(clk_rst.cbn);
    rd++;
    @(tl.cb);
    a_chan.put(1);                       // monitor publishes the A-channel item
  end

  initial begin
    int item;
    logic [31:0] cached, live;
    a_chan.get(item);                    // scoreboard predicts on the A channel
    cached = status(cached_depth);
    live = status(wr - rd);
    $display("cached prediction 0x%0h (legal: 0x2 or 0x10), live prediction 0x%0h", cached, live);
    if (live !== 32'h2 || !(cached inside {32'h2, 32'h10}) || status(32) !== 32'h204)
      $fatal(1, "live status must be 0x2 regardless of Active-region order");
    $display("PASS");
    $finish;
  end
endmodule
