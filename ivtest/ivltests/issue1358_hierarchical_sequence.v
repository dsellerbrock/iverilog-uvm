module top;
  bit clk = 0;
  bit a = 0;
  bit actual = 1;
  int passes = 0;
  int failures = 0;

  source u(.a(1'b1), .actual(1'b0), .b(1'b1));

  assert property (@(posedge clk) u.one)
    passes++;
  else failures++;

  assert property (@(posedge clk) u.with_arg(actual))
    passes++;
  else failures++;

  assert property (@(posedge clk) u.nested(actual))
    passes++;
  else failures++;

  initial begin
    #1 clk = 1;
    #1 clk = 0;
    #1 clk = 1;
    #1;
    if (passes != 5 || failures)
      $fatal(1, "hierarchical sequence=%0d/%0d", passes, failures);
    $display("PASS hierarchical sequence");
    $finish(0);
  end
endmodule

module source(input logic a, input logic actual, input logic b);
  sequence one;
    a;
  endsequence

  sequence with_arg(x);
    a && x;
  endsequence

  sequence nested(x);
    with_arg(x) ##1 b;
  endsequence
endmodule
