module test;
  logic clk = 0, req = 0, ack = 0;
  logic [7:0] din = 0, dout = 0;
  int failures = 0;
  always #5 clk = ~clk;

  sequence s_pipe;
    logic [7:0] v;
    (req, v = din) ##2 (ack && dout == v);
  endsequence
  assert property (@(posedge clk) req |-> s_pipe) else failures++;

  initial begin
    @(negedge clk); req = 1; din = 8'ha5;
    @(negedge clk); req = 0;
    @(negedge clk); ack = 1; dout = 8'ha5;
    @(negedge clk); ack = 0;
    @(negedge clk);
    if (failures != 0) $fatal(1, "sequence local variable failures=%0d", failures);
    $display("PASSED: §16.10 sequence local variable");
    $finish(0);
  end
endmodule
