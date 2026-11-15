// IEEE 1800-2023 16.14.3: a cover property's pass statement "shall be
// executed once for each successful evaluation attempt", and a vacuous
// success is a success (16.14.8). 20.11: $assertvacuousoff stops the
// pass action for vacuous successes only.
module sva_cover_vacuous_pass;
  logic clk = 0, a = 0, b = 0;
  int c1, c2, c3, c4;
  always #5 clk = ~clk;
  // Clock edges at 5, 15, 25, 35, 45, 55. a is 1 only at 25, b only at 35.
  initial begin
    #20 a = 1;
    #10 a = 0; b = 1;
    #10 b = 0;
  end
  cover property (@(posedge clk) a |-> 1'b1) c1++;      // all 5 succeed
  cover property (@(posedge clk) a |=> b) c2++;         // 25 matches at 35
  cover property (@(posedge clk) a |-> b) c3++;         // 25 is a failure
  cover property (@(posedge clk) a ##1 b |-> 1'b1) c4++;// 25 matches at 35
  initial begin
    #52 $display("c1=%0d c2=%0d c3=%0d c4=%0d", c1, c2, c3, c4);
    $assertvacuousoff;
    #10 $display("after vacuousoff c1=%0d c2=%0d c3=%0d c4=%0d", c1, c2, c3, c4);
    $finish;
  end
endmodule
