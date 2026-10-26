module top;
  bit clk = 0, a = 1;
  int hits;

  always #5 clk = ~clk;

  sequence one_tick;
    @(posedge clk) 1'b1;
  endsequence

  cover property (@one_tick a) hits++;

  initial begin
    #6;
    if (hits != 1) $fatal(1, "hits=%0d", hits);
    $display("PASS hits=%0d", hits);
    $finish(0);
  end
endmodule
