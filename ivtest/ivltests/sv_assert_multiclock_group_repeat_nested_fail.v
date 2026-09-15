module test;reg c1=0,c2=0,a=1,b=1,g=1;always #10 c1=~c1;always #15 c2=~c2;
assert property(@(posedge c1)((a##1 b)[*1:2]##1 a)[*1:2]|->@(posedge c2)g);endmodule
