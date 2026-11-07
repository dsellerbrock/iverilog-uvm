// IEEE 1800-2017/2023 16.13.6: triggered/matched hold at the tick where a
// match of the named sequence ends, for variable-length sequences too, and
// "an empty match does not cause triggered/matched to be true".
module issue1190_endpoint_variable_length;
  logic clk = 0, a = 0, b = 0;
  int t = 0;
  always #5 clk = ~clk;
  always @(posedge clk) t <= t + 1;

  sequence win;      a ##[1:3] b;      endsequence
  sequence rep;      a[*2:3] ##1 b;    endsequence
  sequence maybe;    a[*0:1];          endsequence
  sequence opt;      a ##1 b[*0:1] ##1 a; endsequence

  c1: cover property (@(posedge clk) win.triggered) $display("t=%0d win", t);
  c2: cover property (@(posedge clk) rep.matched) $display("t=%0d rep", t);
  c3: cover property (@(posedge clk) maybe.triggered) $display("t=%0d maybe", t);
  c4: cover property (@(posedge clk) opt.triggered) $display("t=%0d opt", t);
  a1: assert property (@(posedge clk) !maybe.matched || a);

  initial begin
    // Sampled: a at ticks 3, 4; b at 5; b at 10 (6 ticks after the last a:
    // no win);
    // a at 12, a at 14. opt with an empty b[*0] is a ##1 a (16.9.2.1), so it
    // ends at 4 only (a at 3 and 4); a at 12 and 14 are not adjacent.
    @(negedge clk);
    @(negedge clk) a = 1;
    @(negedge clk) a = 1;
    @(negedge clk) begin a = 0; b = 1; end
    @(negedge clk) b = 0;
    repeat (3) @(negedge clk);
    @(negedge clk) b = 1;
    @(negedge clk) b = 0;
    @(negedge clk) a = 1;
    @(negedge clk) a = 0;
    @(negedge clk) a = 1;
    @(negedge clk) a = 0;
    repeat (2) @(negedge clk);
    $finish;
  end
endmodule
