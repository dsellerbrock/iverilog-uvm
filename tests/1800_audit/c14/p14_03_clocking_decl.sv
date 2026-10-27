module test;
  reg clk = 0;
  always #5 clk = ~clk;

  reg din = 0;
  reg dout_sig = 0;
  reg io_sig = 0;

  clocking cb @(posedge clk);
    default input #1step output #0;
    input din;
    output dout_sig;
    inout io_sig;
  endclocking

  initial begin
    #1;
    din = 1;
    io_sig = 1;
    @(cb);
    if (cb.din !== 1'b1 || cb.io_sig !== 1'b1) $finish(1);
    cb.dout_sig <= 1'b1;
    cb.io_sig <= 1'b0;
    @(cb);
    if (dout_sig !== 1'b1 || io_sig !== 1'b0) $finish(1);
    $display("PASSED");
    $finish(0);
  end
endmodule
