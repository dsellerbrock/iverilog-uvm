module first_match_implication_cut;
  logic clk=0, a=0, b=0, c=0, d=0, e=0, f=0;
  int failures = 0;
  always #5 clk = ~clk;

  assert property (@(posedge clk) a ##[1:2] b |->
    first_match(c ##[1:2] d ##1 e) ##1 f) else failures++;

  initial begin
    // b and c coincide at the overlapped implication boundary. The early
    // d@1/e@2 endpoint is selected, but f@3 is false. The later d@2/e@3
    // path must be cut even though f@4 is true.
    @(negedge clk) a=1;
    @(negedge clk) a=0; b=1; c=1;
    @(negedge clk) b=0; c=0; d=1;
    @(negedge clk) d=1; e=1;
    @(negedge clk) d=0; e=1;
    @(negedge clk) e=0; f=1;
    @(negedge clk) f=0;
    repeat (3) @(negedge clk);

    $display("first_match_implication_cut_failures=%0d", failures);
    if (failures != 1) $fatal(1, "expected only the selected earliest endpoint to fail");
    $finish(0);
  end
endmodule
