module test;reg c1=0,c2=0,x=1,a=0,b=0,good=1;int p=0,f=0;time at;always #10 c1=~c1;initial begin #35;c2=1;#1;c2=0;end
assert property(@(posedge c1)x##2(a##1 b)[*0]|=>@(posedge c2)good)begin p++;at=$time;end else f++;
initial begin #11;$assertoff(0);#30;if(p!=1||f||at!=35)$fatal(1,"p%0d f%0d at%0t",p,f,at);$display("PASSED");$finish(0);end endmodule
