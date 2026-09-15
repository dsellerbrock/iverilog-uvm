module test;reg c1=0,c2=0,a=1,b=1,good=1;int p=0,f=0;time at;always #10 c1=~c1;initial begin #35;c2=1;#1;c2=0;#39;c2=1;#1;c2=0;end
assert property(@(posedge c1)(a##1 b)[*1:2]|->@(posedge c2)good)p++;else begin f++;at=$time;end
initial begin #11;$assertoff(0);#54;good=0;#11;if(p||f!=1||at!=75)$fatal(1,"p%0d f%0d at%0t",p,f,at);$display("PASSED");$finish(0);end endmodule
