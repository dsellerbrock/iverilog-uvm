module test;
reg c1=0,c2=0,a=1,b=0,c=1,good=1; int p=0,f=0;
always #10 c1=~c1; initial begin #5;forever #10 c2=~c2;end
assert property (@(posedge c1) a ##1 b[*0:1] ##1 c |=> @(posedge c2) good) p++; else f++;
initial begin #11 $assertoff(0); #50; if(p!=1||f)$fatal(1,"p%0d f%0d",p,f);$display("PASSED");$finish(0);end
endmodule
