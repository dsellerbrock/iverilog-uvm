module t; event e; initial #1 -> e; initial begin @e; $display("E1 %0t", $time); end endmodule
