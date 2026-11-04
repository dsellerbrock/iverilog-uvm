module top;
  bit clk = 0;
  bit a = 1;
  bit actual = 1;
  int passes = 0;
  int failures = 0;

  source u(.a(1'b1), .actual(1'b0), .b(1'b1));

  sequence local_seq;
    a;
  endsequence

  assert property (@(posedge clk) u.one)
    passes++;
  else failures++;

  assert property (@(posedge clk) u.with_arg(actual))
    passes++;
  else failures++;

  assert property (@(posedge clk) u.nested(actual))
    passes++;
  else failures++;

  assert property (@(posedge clk) u.wrap(local_seq))
    passes++;
  else failures++;

  initial begin
    #1 clk = 1;
    #1 clk = 0;
    #1 clk = 1;
    #1;
    if (passes != 7 || failures)
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

  sequence local_seq;
    actual;
  endsequence

  sequence wrap(s);
    s;
  endsequence
endmodule
