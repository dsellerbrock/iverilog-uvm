// M8 tail T2 negative: a global clocking declaration only specifies
// the clocking event; clocking items are illegal.
// IEEE 1800-2017 14.14. EXPECT-FAIL-COMPILE
module m8_global_clocking_items;
  logic clk = 0;
  logic [7:0] d;
  global clocking gck @(posedge clk);
    input d;   // error: no items in global clocking
  endclocking
endmodule
