module test;reg c1=0,c2=0,a=1,b=1;always #1 c1=~c1;always #2 c2=~c2;
assert property (@(posedge c1) a[*64:65] |=> @(posedge c2) b); endmodule
