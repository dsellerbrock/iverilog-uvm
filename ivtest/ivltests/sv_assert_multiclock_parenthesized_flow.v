module main;
  logic clk0=0, clk1=0, w=0, x=0, y=0, z=0;
  integer failures=0, hits=0;

  always #5 clk0=~clk0;
  always #7 clk1=~clk1;

  p: assert property (
        @(posedge clk0) w ##1 (x ##1 @(posedge clk1) y) |=> z)
        ;
      else failures++;

  c: cover property (
        @(posedge clk0) w ##1 (x ##1 @(posedge clk1) y) |=> z)
        hits++;

  initial begin
    #1 w=1;
    #6 begin w=0; x=1; end
    #10 begin x=0; y=1; end
    #7 begin y=0; z=1; end
    #2 z=0;
    #50;
    if (failures != 0 || hits != 1)
      $fatal(1, "FAILED -- failures=%0d hits=%0d, expected 0/1",
             failures, hits);
    $display("PASSED");
    $finish(0);
  end
endmodule
