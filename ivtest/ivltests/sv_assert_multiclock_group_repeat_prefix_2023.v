module test;reg c1=0,c2=0,a=1,b=1,prefix=1,good=1;int p=0,f=0;time at;always #10 c1=~c1;initial begin #95;c2=1;#1;c2=0;end
assert property(@(posedge c1)(a##1 b)[*1:2]|=>prefix##1@(posedge c2)good)begin p++;at=$time;end else f++;
initial begin #11;$assertoff(0);#90;if(p!=1||f||at!=95)$fatal(1,"p%0d f%0d at%0t",p,f,at);$display("PASSED");$finish(0);end endmodule
