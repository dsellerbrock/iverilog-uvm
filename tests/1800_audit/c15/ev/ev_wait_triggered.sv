module t; event a; initial #10 -> a; initial begin #10 wait (a.triggered); $display("E3 %0t", $time); end endmodule
