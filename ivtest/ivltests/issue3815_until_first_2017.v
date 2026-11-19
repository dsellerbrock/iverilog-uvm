module issue3815_until_first;
  bit clk;
  bit p = 0, q = 1;
  logic unknown = 1'bx;
  int weak_passes, strong_passes, weak_with_fails, strong_with_fails;
  int dist_fails;

  assert property (@(posedge clk) p until q)
    weak_passes++; else $fatal(1, "first-tick until failed");
  assert property (@(posedge clk) p s_until q)
    strong_passes++; else $fatal(1, "first-tick s_until failed");
  assert property (@(posedge clk) p until_with q)
    $fatal(1, "first-tick until_with passed"); else weak_with_fails++;
  assert property (@(posedge clk) p s_until_with q)
    $fatal(1, "first-tick s_until_with passed"); else strong_with_fails++;
  assert property (@(posedge clk) (unknown dist {1 := 1}) until p)
    $fatal(1, "unknown dist operand passed"); else dist_fails++;

  initial begin
    #1 clk = 1;
    #1;
    if (weak_passes != 1 || strong_passes != 1 ||
        weak_with_fails != 1 || strong_with_fails != 1 || dist_fails != 1)
      $fatal(1, "wrong first-tick verdict counts");
    $display("PASS");
    $finish(0);
  end
endmodule
