module m; logic [7:0] v8=8'b1x0z_1100; logic [15:0] big=16'h0100; logic [3:0] ctl;
initial begin  $display("Q ceilneg=%f exp -2.0", $ceil(-2.7)); end endmodule
