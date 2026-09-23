module top; logic clk = 0; int n;
  initial forever begin @(posedge clk) $display("A (declared first) t=%0t", $time); end
  initial forever begin @(posedge clk) $display("B (declared second) t=%0t", $time); end
  initial begin #1 clk = 1; #1 clk = 0; #1 clk = 1; #1 $finish; end
endmodule
