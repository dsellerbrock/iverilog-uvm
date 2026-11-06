// IEEE 1800-2017/2023 16.9.4: $past_gclk(v) is $past(v,,,@$global_clock) and
// $rose/$fell/$stable/$changed_gclk(v) are the 16.9.3 functions on
// @$global_clock: the sampled value now against the one at the most recent
// strictly prior global clocking tick.
module issue712_past_gclk;
  bit gclk = 0, clk = 0;
  logic [1:0] a = 0;
  int ap = 0, af = 0;
  always #2 gclk = ~gclk;            // posedges at 2, 6, 10, ...
  global clocking g @(posedge gclk); endclocking
  always #8 a = a + 1;               // changes at 8, 16, 24, 32
  initial begin                      // samples at 9, 17, 25, 33, 35
    #9 clk = 1; #1 clk = 0;
    #7 clk = 1; #1 clk = 0;
    #7 clk = 1; #1 clk = 0;
    #7 clk = 1; #1 clk = 0;
    #1 clk = 1; #1 clk = 0;
    #5 $display("assert pass=%0d fail=%0d", ap, af);
    $finish;
  end
  always @(posedge clk)
    $display("%0t a=%0d past=%0d rose=%b fell=%b stable=%b changed=%b", $time, a,
             $past_gclk(a), $rose_gclk(a), $fell_gclk(a), $stable_gclk(a),
             $changed_gclk(a));
  c1: assert property (@(posedge clk) $changed_gclk(a)) ap++; else af++;
endmodule
