// IEEE 1800-2023 16.14.6 (c): a procedural concurrent assertion without a
// clocking event takes the clock of its always procedure's event control.
// This holds when the property is a named sequence instance, with or
// without arguments, as well as for a named property instance.
module sva_proc_named_sequence_clock;
  logic clk = 0, a = 1, b = 0;
  always #5 clk = ~clk;
  int n1 = 0, n2 = 0, n3 = 0, n4 = 0;
  sequence s_arg(x); x; endsequence
  sequence s_plain; a; endsequence
  sequence s_delay(x, y); x ##1 !y; endsequence
  property p_arg(x); x; endproperty
  always @(posedge clk) begin
    assert property (s_arg(a)) n1++;
    assert property (s_plain) n2++;
    assert property (p_arg(a)) n4++;
  end
  // A negedge procedure: the sequence runs on falling edges (10, 20, 30).
  always @(negedge clk) begin
    assert property (s_delay(a, b)) n3++;
  end
  initial #32 begin
    $display("s_arg=%0d s_plain=%0d s_delay=%0d p_arg=%0d", n1, n2, n3, n4);
    $finish;
  end
endmodule
