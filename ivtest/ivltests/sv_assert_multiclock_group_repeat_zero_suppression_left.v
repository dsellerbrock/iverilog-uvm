module test;reg c1=0,c2=0,x=1,a=0,b=0,c=1,good=0;int p=0,f=0;time at;always #10 c1=~c1;initial begin #35;c2=1;#1;c2=0;end
assert property(@(posedge c1)x##0(a##1 b)[*0:1]##1 c|->@(posedge c2)good)begin p++;at=$time;end else begin f++;at=$time;end
initial begin #11;$assertoff(0);#30;if(p!=1||f||at!=10)$fatal(1,"p%0d f%0d at%0t",p,f,at);$display("PASSED");$finish(0);end endmodule
