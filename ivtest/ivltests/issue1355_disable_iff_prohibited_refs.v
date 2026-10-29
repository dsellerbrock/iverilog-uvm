module top;
  bit clk, a;
  always #5 clk = ~clk;

  property local_disable;
    int local_value;
    @(posedge clk) disable iff (local_value) 1'b1;
  endproperty

  sequence seq;
    @(posedge clk) a;
  endsequence

  assert property (local_disable);
  assert property (@(posedge clk) disable iff (seq.matched) 1'b1);
endmodule
