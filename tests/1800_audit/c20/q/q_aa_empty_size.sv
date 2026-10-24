module m; int aa[int];
initial begin aa[1]=1; aa.delete(); $display("Q aa_empty_size=%0d exp 0", $size(aa)); end endmodule
