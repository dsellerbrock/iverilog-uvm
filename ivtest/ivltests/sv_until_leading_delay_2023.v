// Separate direct-leading-delay probe. If the front-end accepts a leading
// cycle delay in a property consequent, both controls must pass.
module leading_delay_boundary_v4;
  bit clk=0, d1=0, d2=0, b1=0, b2=0;
  int f1=0, f2=0;
  always #5 clk=~clk;
  assert property (@(posedge clk) d1 |-> ##1 b1) else f1++;
  assert property (@(posedge clk) d2 |-> ##2 b2) else f2++;
  initial begin
    @(negedge clk) begin d1=1; end
    @(negedge clk) begin d1=0; b1=1; d2=1; end
    @(negedge clk) begin b1=0; d2=0; end
    @(negedge clk) b2=1;
    @(negedge clk) b2=0;
    repeat (2) @(negedge clk); $finish(0);
  end
  final begin
    if (f1||f2) $fatal(1,"direct leading delays f1=%0d f2=%0d",f1,f2);
    $display("PASS: direct leading delays v4");
  end
endmodule
