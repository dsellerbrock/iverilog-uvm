module test;reg clk=0,a=1,b=1;int p=0,f=0;always #10 clk=~clk;
assert property(@(posedge clk)(a##1 b)[*2])p++;else f++;
initial begin #11;$assertoff(0);#70;if(p!=1||f)$fatal(1,"p%0d f%0d",p,f);$display("PASSED");$finish(0);end endmodule
