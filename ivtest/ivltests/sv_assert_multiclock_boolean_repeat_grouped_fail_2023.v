module test; reg c1=0,c2=0,a=1,b=1,c=1; always #5 c1=~c1; always #7 c2=~c2;
assert property (@(posedge c1) (a ##1 b)[*1:2] |=> @(posedge c2) c);
endmodule
