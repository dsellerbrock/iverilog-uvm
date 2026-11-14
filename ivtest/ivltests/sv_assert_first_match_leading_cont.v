module sv_assert_first_match_leading_cont;
  bit clk = 0; always #5 clk = ~clk;
  bit a, b;
  bit [31:0] p1[0:5], f1[0:5], p2[0:5], f2[0:5], p3[0:5], f3[0:5];

  assert property (@(posedge clk) a |-> first_match(##[1:3] b) ##1 !b)
    p1[$time/10]++; else f1[$time/10]++;
  assert property (@(posedge clk) first_match(a ##[1:3] b) ##1 !b)
    p2[$time/10]++; else f2[$time/10]++;
  // The range precedes first_match and launches separate attempts.
  assert property (@(posedge clk) a ##[1:2] first_match(b) ##1 !b)
    p3[$time/10]++; else f3[$time/10]++;

  initial begin
    a = 1; b = 0;
    #10 a = 0; b = 1;
    #20 b = 0;
    #20;
    if (p1[1] != 1 || p1[2] != 1 || f1[2] != 1 || p1[3] != 1 || p1[4] != 1 ||
        f1[1] != 0 || f1[3] != 0 || f1[4] != 0 ||
        p2[1] != 0 || p2[2] != 0 || p2[3] != 0 || p2[4] != 0 ||
        f2[1] != 1 || f2[2] != 2 || f2[3] != 1 || f2[4] != 1 ||
        p3[3] != 1 || f3[2] != 1)
      $fatal(1, "first_match continuation verdict mismatch");
    $display("PASS");
    $finish(0);
  end
endmodule
