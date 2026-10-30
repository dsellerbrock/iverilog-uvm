module issue1495_let_sampled_clock;
  logic clk = 0;
  logic a = 0;

  let past_value(x) = $past(x);

  property p;
    @(posedge clk) past_value(a) == !a;
  endproperty

  a1: assert property (p) else $fatal(1, "let sampled clock mismatch");

  initial begin
    #1 a = 1;
    #1 clk = 1;
    #1 clk = 0;
    #1 a = 0;
    #1 clk = 1;
    #1 $display("ISSUE1495_LET_SAMPLED_CLOCK_PASSED");
    $display("PASSED");
    $finish;
  end
endmodule
