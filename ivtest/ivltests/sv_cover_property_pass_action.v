module test;
  bit clk = 0;
  bit covered = 1;
  int edges = 0;
  int passes = 0;

  always #5 clk = ~clk;
  always @(posedge clk) begin
    edges++;
    $display("EDGE %0t", $time);
  end

  cover property (@(posedge clk) covered) begin
    passes++;
    $display("PASS %0t", $time);
  end

  initial begin
    #26;
    if (edges != 3 || passes != 3) begin
      $display("FAILED edges=%0d passes=%0d", edges, passes);
      $finish(1);
    end
    $display("PASSED");
    $finish(0);
  end
endmodule
