module test;
  reg clk = 0;
  always #5 clk = ~clk;
  reg dout_sig = 0;

  clocking cb @(posedge clk);
    output #0 dout_sig;
  endclocking

  initial begin
    @(cb);
    cb.dout_sig <= 1'b1;
    @(cb);
    if (dout_sig !== 1'b1) $finish(1);
    $display("PASSED");
    $finish(0);
  end
endmodule
