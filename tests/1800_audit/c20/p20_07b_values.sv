module p20e;
logic [3:0][2:1] n [1:5][2:8]; typedef logic [16:1] Word; Word Ram[0:9]; typedef int DT[];
int a[3][][5]; int aa[int]; integer N; shortint SI; byte BY; logic [7:0] V;
initial begin
 $display("Q dims_Word=%0d exp1  unp_V=%0d exp0  unp_a=%0d exp3", $dimensions(Word), $unpacked_dimensions(V), $unpacked_dimensions(a));
 $display("Q Word size=%0d exp16 left=%0d exp16 right=%0d exp1 | Ram size2=%0d exp16 size=%0d exp10", $size(Word), $left(Word), $right(Word), $size(Ram,2), $size(Ram));
 $display("Q int N left=%0d exp31 right=%0d exp0 | SI left=%0d exp15 | BY left=%0d exp7 size=%0d exp8 | type int left=%0d exp31", $left(N), $right(N), $left(SI), $right(N), $left(BY), $size(BY), $left(int));
 aa[5]=1; aa[2]=1; aa[9]=1;
 $display("Q aa left=%0d exp0 right=%0d exp>=9 low=%0d exp2 high=%0d exp9 incr=%0d exp-1 size=%0d exp3", $left(aa), $right(aa), $low(aa), $high(aa), $increment(aa), $size(aa));
 aa.delete();
 $display("Q aa_empty low=%0d expx high=%0d expx size=%0d exp0", $low(aa), $high(aa), $size(aa));
 a[2]=new[4];
 $display("Q a dims size1=%0d exp3 size3=%0d exp5 a2size=%0d exp4 a1size=%0d exp0", $size(a,1), $size(a,3), $size(a[2],1), $size(a[1],1));
 $display("Q DT size=%0d (the standard says an error)", $size(DT));
 $display("Q a size2=%0d (the standard says ERROR, dimension 2 is dynamic)", $size(a,2));
end endmodule
