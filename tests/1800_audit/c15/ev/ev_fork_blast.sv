module t; event blast; initial begin fork -> blast; begin wait (blast.triggered); $display("E5"); end join end endmodule
