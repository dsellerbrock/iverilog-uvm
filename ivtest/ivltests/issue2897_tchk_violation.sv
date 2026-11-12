module top;
  reg clk = 0, d = 0, notifier = 0;
  specify
    $setup(d, posedge clk, 5, notifier);
  endspecify
  initial begin
    #10 d = 1;
    #2 clk = 1;
    #10 $display("DONE notifier=%0d", notifier);
    $display("PASSED");
    $finish;
  end
endmodule
