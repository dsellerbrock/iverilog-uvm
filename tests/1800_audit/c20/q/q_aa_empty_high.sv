module m; int aa[int];
initial begin aa[1]=1; aa.delete(); $display("Q aa_empty_high=%0d exp x", $high(aa)); end endmodule
