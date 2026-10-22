module test;
  logic clk = 0, req = 0, ack = 0;
  logic [7:0] din = 0, dout = 0;
  int failures = 0;
  always #5 clk = ~clk;

  property p_pipe;
    logic [7:0] v;
    @(posedge clk) (req, v = din) |-> ##2 (ack && dout == v);
  endproperty
  assert property (p_pipe) else failures++;

  initial begin
    @(negedge clk); req = 1; din = 8'h42;
    @(negedge clk); req = 0;
    @(negedge clk); ack = 1; dout = 8'h42;
    @(negedge clk); ack = 0;
    @(negedge clk);
    if (failures != 0) $fatal(1, "property local variable failures=%0d", failures);
    $display("PASSED: §16.10 property local variable");
    $finish(0);
  end
endmodule
