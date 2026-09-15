module test;reg c1=0,c2=0,a=0,good=1;int p=0,f=0;always #10 c1=~c1;always #15 c2=~c2;
assert property(@(posedge c1)a|=>@(posedge c2)good)p++;else f++;
initial begin #1;$assertoff(0);#60;if(p||f)$fatal(1,"disabled vacuity p%0d f%0d",p,f);$display("PASSED");$finish(0);end endmodule
