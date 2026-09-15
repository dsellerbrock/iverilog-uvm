module test;reg c1=0,c2=0,a=1,b=1,g=1;int p=0,f=0;time at;always #10 c1=~c1;initial begin #75;c2=1;#1;c2=0;end
assert property(@(posedge c1)(a##1 b)[*2]##1@(posedge c2)g)begin p++;at=$time;end else f++;
initial begin #11;$assertoff(0);#70;if(p!=1||f||at!=75)$fatal(1,"p%0d f%0d at%0t",p,f,at);$display("PASSED");$finish(0);end endmodule
