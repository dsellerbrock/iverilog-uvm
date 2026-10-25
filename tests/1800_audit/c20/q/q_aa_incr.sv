module m; int aa[int];
initial begin aa[5]=1; aa[2]=1; aa[9]=1; $display("Q aa_incr=%0d exp -1", $increment(aa)); end endmodule
