module t; event nb; int o = -1; initial begin #5 ->> nb; o = nb.triggered; $display("E6 %0d", o); end initial begin @nb; $display("E6B %0t", $time); end endmodule
