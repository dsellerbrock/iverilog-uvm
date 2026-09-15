module test;reg c1=0,c2=0,a=0,b=0,good=1;int p=0,f=0;time at;always #10 c1=~c1;always #10 c2=~c2;
assert property(@(posedge c1)(a##1 b)[*0]|=>@(posedge c2)good)begin p++;at=$time;end else f++;
initial begin #11;$assertoff(0);#10;if(p!=1||f||at!=10)$fatal(1,"p%0d f%0d at%0t",p,f,at);$display("PASSED");$finish(0);end endmodule
