module issue1180_global_clock_sva;
  bit clk = 0, a = 1;
  int hits;

  always #5 clk = ~clk;

  global clocking global_cb @(posedge clk);
  endclocking

  cover property (@$global_clock a) hits++;

  initial begin
    #6;
    if (hits != 1)
      $fatal(1, "hits=%0d", hits);
    $display("global clock assertion PASS");
    $finish(0);
  end
endmodule
