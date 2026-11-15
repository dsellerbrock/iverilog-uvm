// IEEE 1800-2017/2023 16.5.1: the sampled value of const'(x) in a
// concurrent assertion is the current value of x, so an NBA update made
// in the clock's own time step is visible. Other operands keep their
// Preponed (sampled) values.
module sv_const_cast_sva_current;
  bit clk = 0;
  int cnt = 1;
  int d = 1;

  always #5 clk = ~clk;
  always @(posedge clk) begin
    cnt <= cnt + 1;
    d <= d + 1;
  end

  // Fail at t=5 (cnt=2), t=15 (cnt=3), t=25 (cnt=4) respectively.
  a1: assert property (@(posedge clk) const'(cnt) != 2)
    else $display("a1 fail t=%0t cnt=%0d", $time, cnt);
  a2: assert property (@(posedge clk) 1 |-> const'(cnt) != 3)
    else $display("a2 fail t=%0t cnt=%0d", $time, cnt);
  a3: assert property (@(posedge clk) 1 ##1 const'(cnt) != 4)
    else $display("a3 fail t=%0t cnt=%0d", $time, cnt);

  // Never fail: d is sampled (pre-NBA), const'(cnt) is current, and
  // $past(cnt) is the sample from the previous clock.
  a4: assert property (@(posedge clk) d + 1 == const'(cnt))
    else $display("a4 FAILED t=%0t", $time);
  a5: assert property (@(posedge clk) const'(cnt) == $past(cnt) + 2)
    else $display("a5 FAILED t=%0t", $time);

  initial begin
    #46;
    $display("done");
    $finish;
  end
endmodule
