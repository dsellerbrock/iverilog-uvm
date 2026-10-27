module m; int aa[int];
initial begin aa[1]=1; aa.delete(); $display("Q aa_empty_low=%0d exp x", $low(aa)); end endmodule
