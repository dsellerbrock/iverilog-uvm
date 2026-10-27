module t; event a; bit v; initial #10 -> a; initial begin #11 begin v = a.triggered; $display("E4 %b", v); end end endmodule
