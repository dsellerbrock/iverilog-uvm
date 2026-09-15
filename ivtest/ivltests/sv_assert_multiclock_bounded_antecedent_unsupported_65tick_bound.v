module test;
reg c1,c2,a,b,good;
assert property (@(posedge c1) a ##[1:64] b |-> @(posedge c2) good);
endmodule
