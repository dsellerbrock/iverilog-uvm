module m; logic [7:0] v8=8'b1x0z_1100; logic [15:0] big=16'h0100; logic [3:0] ctl;
initial begin  $display("Q co2=%0d exp 4", $countones(8'b1111_0000)); end endmodule
